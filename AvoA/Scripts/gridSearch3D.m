clear; clc; close all;

%% Load Info and Image
disp('Scanning images...');
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20241007/series/';

files1 = dir(fullfile(dicomFolder1, '*.dcm'));
files2 = dir(fullfile(dicomFolder2, '*.dcm'));

scan1 = [];
for i = 1:length(files1)
    slice = dicomread(fullfile(files1(i).folder, files1(i).name));
    scan1(:, :, i) = slice;
end

scan2 = [];
for i = 1:length(files2)
    slice = dicomread(fullfile(files2(i).folder, files2(i).name));
    scan2(:, :, i) = slice;
end

info1 = dicominfo(fullfile(files1(1).folder, files1(1).name));
info2 = dicominfo(fullfile(files2(1).folder, files2(1).name));

%% Rescale Images
im1_rescaled = info1.RescaleSlope * scan1 + info1.RescaleIntercept;
im2_rescaled = info2.RescaleSlope * scan2 + info2.RescaleIntercept;

%% Threshold & Downsample Images
disp('Thresholding...');
threshold = 300;
imBW1 = im1_rescaled > threshold;
imBW2 = im2_rescaled > threshold;

scale = 10;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

step = 2;
fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);

im1_rescaled_down = im1_rescaled(1:step:end, 1:step:end, 1:step:end);
im2_rescaled_down = im2_rescaled(1:step:end, 1:step:end, 1:step:end);

%% Get References
ref1 = imref3d(size(im1_rescaled), ...
               info1.PixelSpacing(1), ... % X spacing
               info1.PixelSpacing(2), ... % Y spacing
               info1.SliceThickness);     % Z spacing

ref2 = imref3d(size(im2_rescaled), ...
               info2.PixelSpacing(1), ...
               info2.PixelSpacing(2), ...
               info2.SliceThickness);

adjustedPixelSpacing1 = info1.PixelSpacing * step;
adjustedPixelSpacing2 = info2.PixelSpacing * step;

adjustedSliceThickness1 = info1.SliceThickness * step;
adjustedSliceThickness2 = info2.SliceThickness * step;

ref1_down = imref3d(size(fixedImageBW_down), ...
                    adjustedPixelSpacing1(1), ... % X spacing
                    adjustedPixelSpacing1(2), ... % Y spacing
                    adjustedSliceThickness1);     % Z spacing

ref2_down = imref3d(size(movingImageBW_down), ...
                    adjustedPixelSpacing2(1), ...
                    adjustedPixelSpacing2(2), ...
                    adjustedSliceThickness2);

%% Perform Grid Search
% Define parameter ranges
gradientMagnitudeToleranceRange = [1e-6, 1e-4, 1e-2];
minimumStepLengthRange = [1e-7, 1e-5, 1e-3];
maximumStepLengthRange = [6.25e-2, 6.25e-4, 6.25e-6];
maximumIterationsRange = 100;
relaxationFactorRange = [0.3, 0.5, 0.7];

% Create a grid of parameter combinations
[gradTol, minStepLen, maxStepLen, maxIter, relaxFactor] = ndgrid( ...
    gradientMagnitudeToleranceRange, ...
    minimumStepLengthRange, ...
    maximumStepLengthRange, ...
    maximumIterationsRange, ...
    relaxationFactorRange);

% Initialize variables to store results
numCombinations = numel(gradTol);
similarityScores = zeros(numCombinations, 1);
bestParams = [];

% Loop over each combination
parfor idx = 1:numCombinations
    % Track Progress
    fprintf('Processing combination %d of %d...\n', idx, numCombinations);

    % Extract parameters
    gradTolerance = gradTol(idx);
    minStepLength = minStepLen(idx);
    maxStepLength = maxStepLen(idx);
    maxIterations = maxIter(idx);
    relaxationFactor = relaxFactor(idx);
    
    % Create optimizer and modify parameters
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.GradientMagnitudeTolerance = gradTolerance;
    optimizer.MinimumStepLength = minStepLength;
    optimizer.MaximumStepLength = maxStepLength;
    optimizer.MaximumIterations = maxIterations;
    optimizer.RelaxationFactor = relaxationFactor;

    % Perform registration
    try
        tform = imregtform(movingImageBW_down, ref2_down, ...
            fixedImageBW_down, ref1_down, 'similarity', optimizer, metric);
        registeredImage = imwarp(movingImageBW_down, ref2_down, tform, 'OutputView', ref1_down);
        
        % Evaluate similarity (e.g., Mean Squared Error)
        mse = immse(double(registeredImage), double(fixedImageBW_down));
        similarityScores(idx) = mse;
    catch
        % Handle failures gracefully
        similarityScores(idx) = Inf; % Assign a large value for failed registrations
    end
end

% Find the best parameters
[~, bestIdx] = min(similarityScores);
bestParams.GradientMagnitudeTolerance = gradTol(bestIdx);
bestParams.MinimumStepLength = minStepLen(bestIdx);
bestParams.MaximumStepLength = maxStepLen(bestIdx);
bestParams.MaximumIterations = maxIter(bestIdx);
bestParams.RelaxationFactor = relaxFactor(bestIdx);

% Display best parameters and corresponding similarity score
disp('Best Parameters:');
disp(bestParams);
disp('Best Similarity Score:');
disp(similarityScores(bestIdx));

%% Test Params
% Create optimizer and metric
[optimizer, metric] = imregconfig('monomodal');

% Apply the best parameters to the optimizer
optimizer.GradientMagnitudeTolerance = bestParams.GradientMagnitudeTolerance;
optimizer.MinimumStepLength = bestParams.MinimumStepLength;
optimizer.MaximumStepLength = bestParams.MaximumStepLength;
optimizer.MaximumIterations = bestParams.MaximumIterations;
optimizer.RelaxationFactor = bestParams.RelaxationFactor;

clc;
delete('optimization_log.txt');
diary('optimization_log.txt');

tform = imregtform(movingImageBW_down, ref2_down, fixedImageBW_down, ...
    ref1_down, 'similarity', optimizer, metric, 'DisplayOptimization', true);

diary off;

plotOptimizationResults('optimization_log.txt')

registeredImage = imwarp(movingImageBW_down, ref2_down, tform, 'OutputView', ref1_down);

%%
interactiveRegVis(registeredImage, fixedImageBW_down, 'z');