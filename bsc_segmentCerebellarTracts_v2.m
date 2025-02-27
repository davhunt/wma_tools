function [classificationOut] =bsc_segmentCerebellarTracts_v2(wbfg,atlas,experimentalBool,varargin)
% This function automatedly segments cerebellar
% from a given whole brain fiber group using the subject's 2009 DK
% freesurfer parcellation.  Subsections may come later.

% Inputs:
% -wbfg: a whole brain fiber group structure
% -experimentalBool: toggle for experimental tracts
% -varargin: priors from previous steps

% Outputs:
%  classificationOut:  standardly constructed classification structure
%  Same for the other tracts
% (C) Daniel Bullock, 2019, Indiana University

sideLabel={'left','right'};
categoryPrior=varargin{1};
classificationOut=[];
classificationOut.names=[];
classificationOut.index=zeros(length(wbfg.fibers),1);

cbROINums=[7 8;46 47];
thalamusLut=[10 49];

[inflatedAtlas] =bsc_inflateLabels(atlas,2);

LeftCBRoi=bsc_roiFromAtlasNums(inflatedAtlas,cbROINums(1,:) ,1);
RightCBRoi=bsc_roiFromAtlasNums(inflatedAtlas,cbROINums(2,:) ,1);
[~, leftCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{LeftCBRoi}], {'endpoints'}, 'dud');
[~, rightCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{RightCBRoi}], {'endpoints'}, 'dud');
spinoCebBool=or(bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_spinal_interHemi'),bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_spinal'));
SpineTop= bsc_planeFromROI_v2(16,'superior',atlas);
[~, SpineTopBool]=wma_SegmentFascicleFromConnectome(wbfg, [{SpineTop}], {'not'}, 'dud');

classificationOut=bsc_concatClassificationCriteria(classificationOut,'leftSpinoCerebellar',leftCebBool,spinoCebBool,SpineTopBool);
classificationOut=bsc_concatClassificationCriteria(classificationOut,'rightSpinoCerebellar',rightCebBool,spinoCebBool,SpineTopBool);
SpineLimit= bsc_planeFromROI_v2(16,'anterior',atlas);
[~, posteriorStreams]=wma_SegmentFascicleFromConnectome(wbfg, [{SpineLimit}], {'not'}, 'dud');

for leftright= [1,2]
    
    %sidenum is basically a way of switching  between the left and right
    %hemispheres of the brain in accordance with freesurfer's ROI
    %numbering scheme. left = 1, right = 2
    sidenum=10000+leftright*1000;
    
    %% Ipsilateral connections
    CBRoi=bsc_roiFromAtlasNums(inflatedAtlas,cbROINums(leftright,:) ,1);
    ThalROI=bsc_roiFromAtlasNums(inflatedAtlas,thalamusLut(leftright) ,1);
    antCebSplit= bsc_planeFromROI_v2(thalamusLut(leftright),'anterior',atlas);
    thalTop=bsc_planeFromROI_v2(thalamusLut(leftright),'superior',atlas)
    
    %motorCerebellum
    frontoMotorLimit= bsc_planeFromROI_v2(170+sidenum, 'anterior',inflatedAtlas);
    frontMedROI=bsc_roiFromAtlasNums(inflatedAtlas,[116]+sidenum ,1);
    frontoMedMotorROI=bsc_modifyROI_v2(inflatedAtlas,frontMedROI, frontoMotorLimit, 'posterior');
    MotorROI=bsc_roiFromAtlasNums(inflatedAtlas,[168 128 146 129 170 103 ]+sidenum ,1);
    MotorROI=bsc_mergeROIs(frontoMedMotorROI,MotorROI);
    
    [~, AnterioFrontoBool]=wma_SegmentFascicleFromConnectome(wbfg, [{CBRoi} {antCebSplit}], {'endpoints','and'}, 'dud');
    [~, middleFrontoBool]=wma_SegmentFascicleFromConnectome(wbfg, [{CBRoi} {antCebSplit}], {'endpoints','not'}, 'dud');
    [~, thalCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{CBRoi} {ThalROI} {SpineLimit} {thalTop}], {'endpoints','endpoints','not','not',}, 'dud');
    [~, motorCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{CBRoi} {MotorROI}], {'endpoints','endpoints'}, 'dud');
    [~, thisCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{CBRoi}], {'endpoints'}, 'dud');
    
    
    %[indexBool] = bsc_extractStreamIndByName(classification,tractName)
    motorCebBool=motorCebBool&or(bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_frontal')),bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_parietal')));
    AnterioFrontoBool=AnterioFrontoBool&bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_frontal'));
    middleFrontoBool=~motorCebBool&middleFrontoBool&bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_frontal'));
    thalCebBool=thalCebBool&bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_subcortical'));
    occipitoCebBool=posteriorStreams&thisCebBool&bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_occipital'));
    parietoCebBool=posteriorStreams&thisCebBool&~motorCebBool&bsc_extractStreamIndByName(categoryPrior,strcat(sideLabel{leftright},'cerebellum_to_parietal'));
    
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'MotorCerebellar'),motorCebBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},' AnterioFrontoCerebellar'),AnterioFrontoBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ThalamicoCerebellar'),thalCebBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'OccipitoCerebellar'),occipitoCebBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ParietoCerebellar'),parietoCebBool);
    
    if experimentalBool
          classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'MiddleFrontoCerebellar'),middleFrontoBool);
  
         classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'MiddleFrontoBoolCerebellar'),middleFrontoBool);
    end

    %% Contralateral connections
    if leftright==1
        otherCBRoi=bsc_roiFromAtlasNums(inflatedAtlas,cbROINums(2,:) ,1);
        otherWM=bsc_roiFromAtlasNums(atlas,41 ,1);
    else
        otherCBRoi=bsc_roiFromAtlasNums(inflatedAtlas,cbROINums(1,:) ,1);
         otherWM=bsc_roiFromAtlasNums(atlas,2 ,1);
    end
    
    [~,notThese]=wma_SegmentFascicleFromConnectome(wbfg, [{otherWM}], {'and'}, 'dud');
  
    
    [~, contraAnterioFrontoBool]=wma_SegmentFascicleFromConnectome(wbfg, [{otherCBRoi} {antCebSplit}], {'endpoints','and'}, 'dud');
    [~, contramiddleFrontoBool]=wma_SegmentFascicleFromConnectome(wbfg, [{otherCBRoi} {antCebSplit}], {'endpoints','not'}, 'dud');
    [~, contrathalCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{otherCBRoi} {ThalROI}, {SpineLimit}], {'endpoints','endpoints','not'}, 'dud');
    [~, contramotorCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{otherCBRoi} {MotorROI}], {'endpoints','endpoints'}, 'dud');
    [~, contrathisCebBool]=wma_SegmentFascicleFromConnectome(wbfg, [{otherCBRoi}], {'endpoints'}, 'dud');
    
        %[indexBool] = bsc_extractStreamIndByName(classification,tractName)
    
    contramotorCebBool=~notThese&contramotorCebBool&or( bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_frontal_interHemi'), bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_parietal_interHemi'));
    contraAnterioFrontoBool=~notThese&contraAnterioFrontoBool&bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_frontal_interHemi');
    contramiddleFrontoBool=~notThese&~contramotorCebBool&contramiddleFrontoBool&bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_frontal_interHemi');
    contrathalCebBool=~notThese&contrathalCebBool&bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_subcortical_interHemi');
    contraoccipitoCebBool=~notThese&posteriorStreams&contrathisCebBool&bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_occipital_interHemi');
    contraparietoCebBool=~notThese&posteriorStreams&contrathisCebBool&~contramotorCebBool&bsc_extractStreamIndByName(categoryPrior,'cerebellum_to_parietal_interHemi');

    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraMotorCerebellar'),contramotorCebBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraAnterioFrontoCerebellar'),contraAnterioFrontoBool);
      
     if experimentalBool
          classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraOccipitoCerebellar'),contraoccipitoCebBool);
    classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraParietoCerebellar'),contraparietoCebBool);
    
         classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraMiddleFrontoBoolCerebellar'),contramiddleFrontoBool);
         classificationOut=bsc_concatClassificationCriteria(classificationOut,strcat(sideLabel{leftright},'ContraThalamicoCerebellar'),contrathalCebBool);
     end
     
end
end

