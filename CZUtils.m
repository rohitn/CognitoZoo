(* ::Package:: *)

CZDisplayObject[object_]:={object[[2]],Text[Style[object[[1]],White,12],{20,20}+object[[2,1]],Background->Black]}


CZPascalClasses = {"aeroplane", "bicycle", "bird", "boat", "bottle", "bus", "car", "cat", "chair", "cow", "diningtable",
   "dog", "horse", "motorbike", "person", "pottedplant", "sheep", "sofa", "train", "tvmonitor"};


CZImageConformer[ dims_, fitting_ ] := Function[{image},First@ConformImages[ {image}, dims, fitting ]];


CZIntersection[a_, b_] := Module[{xa=Max[a[[1,1]],b[[1,1]]],ya=Max[a[[1,2]],b[[1,2]]],xb=Min[a[[2,1]],b[[2,1]]],yb=Min[a[[2,2]],b[[2,2]]]},
   If[xa>xb||ya>yb,0,(xb-xa+1)*(yb-ya+1)]]
CZArea[a_] := ( a[[1,1]]-a[[2,1]] ) * ( a[[1,2]]-a[[2,2]] )
CZUnion[a_,b_] := CZArea[a] + CZArea[b] - CZIntersection[a, b]


(* Had considered using RegionIntersection/RegionUnion but this was overly general and unacceptably slow in practice.
   Not uncommon to see 100 raw detections, hence 10,000 pairs to evaluate.
*)
CZIntersectionOverUnion[a_, b_]:= 
   CZIntersection[ a, b ] / CZUnion[a, b]


(*
   Note: requires format list of {prob,metrics,Rectangle[{xmin,ymin},{xmax,ymax}]}
   It is sensitive to that xmin,ymin,xmax,ymax ordering and will not
   work if it is wrong way round (ie corners in wrong order)
*)
CZTakeMaxProbRectangle[ objects_ ] := (First@SortBy[objects,-#[[1]]&])[[{2,3}]];
CZTakeWeightedRectangle[ objects_ ] := {
   Round[Total[objects[[All,1]]*List@@@objects[[All,2]]]/Total[objects[[All,1]]]],
   Rectangle@@Round[Total[objects[[All,1]]*List@@@objects[[All,3]]]/Total[objects[[All,1]]]]};
SyntaxInformation[ NMSMethod ]= {"ArgumentsPattern"->{_}};
SyntaxInformation[ NMSIntersectionOverUnionThreshold ]= {"ArgumentsPattern"->{_}};
Options[ CZNonMaxSuppression ] = {
   NMSMethod->CZTakeMaxProbRectangle,
   NMSIntersectionOverUnionThreshold->.25
};
CZNonMaxSuppression[ opts:OptionsPattern[] ] := Function[ {objects},
   OptionValue[ NMSMethod ] /@ Gather[ objects, (CZIntersectionOverUnion[#1[[3]],#2[[3]]]>OptionValue[ NMSIntersectionOverUnionThreshold] )& ] ];


(*
   Note: requires format list of {class, prob, metrics, Rectangle[{xmin,ymin},{xmax,ymax}]}
   It is sensitive to that xmin,ymin,xmax,ymax ordering and will not
   work if it is wrong way round (ie corners in wrong order)
*)
(* Does Non Max Suppression seperately by object class *)
Options[ CZNonMaxSuppressionPerClass ] = Options[ CZNonMaxSuppression ];
CZNonMaxSuppressionPerClass[opts:OptionsPattern[] ] := Function[ { objects },
      Flatten[Map[Function[{objectsInClass},{objectsInClass[[1,1]],#[[1]],#[[2]]}&/@CZNonMaxSuppression[ opts ][objectsInClass[[All,2;;4]] ]],GatherBy[objects,#[[1]]&]],1]]


CZDeconformRectangles[ {}, _, _, _ ] := {};
CZDeconformRectangles[ rboxes_, image_, netDims_, "Fit" ] :=
   With[{netAspectRatio = netDims[[2]]/netDims[[1]]},
      With[ {
         boxes = Map[{#[[1]],#[[2]]}&,rboxes],
         padding = If [ ImageAspectRatio[image] < netAspectRatio,
            {0,(ImageDimensions[image][[1]]*netAspectRatio-ImageDimensions[image][[2]])/2},
            {(ImageDimensions[image][[2]]*(1/netAspectRatio)-ImageDimensions[image][[1]])/2,0}
            ],
         scale = If [ ImageAspectRatio[image] < netAspectRatio, ImageDimensions[image][[1]]/netDims[[1]], ImageDimensions[image][[2]]/netDims[[2]] ]
         },rt1=netAspectRatio;rt2=scale;
         Map[Rectangle[Round[#[[1]]],Round[#[[2]]]]&, Transpose[Transpose[boxes,{2,3,1}]*scale - padding,{3,1,2}]]
   ]];
CZDeconformRectangles[ rboxes_, image_, netDims_, "Stretch" ] := 
   Module[ {
      boxes = Map[{#[[1]],#[[2]]}&,rboxes] },
      Map[Rectangle[Round[#[[1]]],Round[#[[2]]]]&, Transpose[Transpose[boxes,{2,3,1}]*ImageDimensions[image]/netDims,{3,1,2}]]
   ]


(* Implicitly assumes that the rectangles are last entry 4 in the list of objects.
   So { {class1, prob1, metrics1, rect1 }, ... }
*)
CZObjectsDeconformer[ image_, netDims_, fitting_ ] := Function[{ objects },
   If[
      objects=={},
      {},
      Transpose[ MapAt[ CZDeconformRectangles[ #, image, netDims, fitting ]&, Transpose[ objects ], -1 ] ] ] ]
