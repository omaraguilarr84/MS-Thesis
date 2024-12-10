clear; clc; close all;

%% Load Images
fixedImage = dicomread('../Data/20240830/series/IM-0002-0066.dcm');
movingImage = dicomread('../Data/20240910/series/IM-0001-0443.dcm');

%% Threshold Images
fixedImage_double = double(fixedImage);
movingImage_double = double(movingImage);

threshold = 1100;
fixedImageBW = fixedImage_double > threshold;
movingImageBW = movingImage_double > threshold;

fixedImageBW_double = double(fixedImageBW);
movingImageBW_double = double(movingImageBW);

%% Perform Grid Search
% Define parameter ranges
gradientMagnitudeToleranceRange = [1e-8, 1e-6, 1e-4];
minimumStepLengthRange = [1e-9, 1e-7, 1e-5];
maximumStepLengthRange = [6.25e-2, 6.25e-4, 6.25e-6];
maximumIterationsRange = [150, 200, 250];
relaxationFactorRange = [0.3, 0.5, 0.7];
transformTypeRange = {'rigid', 'similarity', 'affine'};
pyramidLevelsRange = [2, 4, 6];

% Create a grid of parameter combinations
[gradTol, minStepLen, maxStepLen, maxIter, relaxFactor, tType, pyrLevel] = ndgrid( ...
    gradientMagnitudeToleranceRange, ...
    minimumStepLengthRange, ...
    maximumStepLengthRange, ...
    maximumIterationsRange, ...
    relaxationFactorRange, ...
    transformTypeRange, ...
    pyramidLevelsRange);

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
    transformType = tType{idx};
    pyramidLevel = pyrLevel(idx);
    
    % Create optimizer and modify parameters
    [optimizer, metric] = imregconfig('monomodal');
    optimizer.GradientMagnitudeTolerance = gradTolerance;
    optimizer.MinimumStepLength = minStepLength;
    optimizer.MaximumStepLength = maxStepLength;
    optimizer.MaximumIterations = maxIterations;
    optimizer.RelaxationFactor = relaxationFactor;

    % Perform registration
    try
        registeredImage = imregister(movingImageBW_double, fixedImageBW_double, transformType, optimizer, metric, 'PyramidLevels', pyramidLevel);
        
        % Evaluate similarity (e.g., Mean Squared Error)
        mse = immse(double(registeredImage), double(fixedImageBW));
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
bestParams.TransformType = tType{bestIdx};
bestParams.PyramidLevels = pyrLevel(bestIdx);

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

transformType = bestParams.TransformType;
pyramidLevel = bestParams.PyramidLevels;

% Perform registration with the optimized parameters
registeredImage = imregister(movingImageBW_double, fixedImageBW_double, transformType, optimizer, metric, 'PyramidLevels', pyramidLevel);

% Visualize the result
imshowpair(fixedImageBW, registeredImage, 'falsecolor');
title('Optimized Registration Result');
