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
threshold = 500;
imBW1 = im1_rescaled > threshold;
imBW2 = im2_rescaled > threshold;

scale = 10;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

step = 2; % Increased downsampling factor
fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);

im1_rescaled_down = im1_rescaled(1:step:end, 1:step:end, 1:step:end);
im2_rescaled_down = im2_rescaled(1:step:end, 1:step:end, 1:step:end);

%% Get References
shell = find(any(any(fixedImageBW_down > 0, 1), 2));
fixedShell = fixedImageBW_down(:, :, shell);
movingShell = movingImageBW_down(:, :, shell);

adjustedPixelSpacing1 = info1.PixelSpacing * step;
adjustedPixelSpacing2 = info2.PixelSpacing * step;

adjustedSliceThickness1 = info1.SliceThickness * step;
adjustedSliceThickness2 = info2.SliceThickness * step;

ref1_down = imref3d(size(fixedShell), ...
    adjustedPixelSpacing1(1), ...
    adjustedPixelSpacing1(2), ...
    adjustedSliceThickness1);

ref2_down = imref3d(size(movingShell), ...
    adjustedPixelSpacing2(1), ...
    adjustedPixelSpacing2(2), ...
    adjustedSliceThickness2);

%% Bayesian Optimization with Improvements
disp('Starting Bayesian Optimization...');

% Check if a parallel pool is already open
pool = gcp('nocreate'); % Get the current parallel pool without creating a new one
if isempty(pool)
    % No pool is active, so create a new one
    parpool('local', 8);
else
    % A pool is already active, adjust workers if necessary
    if pool.NumWorkers ~= 8
        delete(pool); % Delete the existing pool
        parpool('local', 8); % Create a new one with 8 workers
    end
end

% Define initial parameter values as a table
initialX = table( ...
    1e-4, ...      % GradientMagnitudeTolerance
    1e-4, ...    % MinimumStepLength
    6.25e-4, ...     % MaximumStepLength
    300, ...       % MaximumIterations
    0.3, ...       % RelaxationFactor
    2, ...         % PyramidLevel
    'VariableNames', {'GradientMagnitudeTolerance', 'MinimumStepLength', 'MaximumStepLength', ...
                      'MaximumIterations', 'RelaxationFactor', 'PyramidLevel'});

% Bayesian optimization call with the corrected InitialX
results = bayesopt(@(params)objFcn(params, movingShell, ref2_down, fixedShell, ref1_down), ...
    [optimizableVariable('GradientMagnitudeTolerance', [1e-9, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MinimumStepLength', [1e-9, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MaximumStepLength', [1e-6, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MaximumIterations', [50, 300], 'Type', 'integer'), ...
     optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
     optimizableVariable('PyramidLevel', [1, 3], 'Type', 'integer')], ...
    'Verbose', 1, ...
    'AcquisitionFunctionName', 'lower-confidence-bound', ...
    'MaxObjectiveEvaluations', 100, ...
    'UseParallel', true, ...
    'InitialX', initialX);

%% Extract Best Parameters
disp('Best Parameters:');
disp(results.XAtMinObjective);

%% Interactive Visualization
[optimizer, metric] = imregconfig('monomodal');
optimizer.GradientMagnitudeTolerance = results.XAtMinObjective.GradientMagnitudeTolerance;
optimizer.MinimumStepLength = results.XAtMinObjective.MinimumStepLength;
optimizer.MaximumStepLength = results.XAtMinObjective.MaximumStepLength;
optimizer.MaximumIterations = results.XAtMinObjective.MaximumIterations;
optimizer.RelaxationFactor = results.XAtMinObjective.RelaxationFactor;

% Perform registration with the best parameters
bestPyramidLevel = results.XAtMinObjective.PyramidLevel;
tform = imregtform(movingShell, ref2_down, fixedShell, ...
    ref1_down, 'similarity', optimizer, metric, ...
    'PyramidLevels', bestPyramidLevel);

registeredImage = imwarp(movingShell, ref2_down, tform, 'OutputView', ref1_down);

interactiveRegVis(registeredImage, fixedShell, 'z');

%% Objective Function Definition
function score = objFcn(params, movingShell, ref2_down, fixedShell, ref1_down)
    try
        % Create optimizer and modify parameters
        [optimizer, metric] = imregconfig('monomodal');
        optimizer.GradientMagnitudeTolerance = params.GradientMagnitudeTolerance;
        optimizer.MinimumStepLength = params.MinimumStepLength;
        optimizer.MaximumStepLength = params.MaximumStepLength;
        optimizer.MaximumIterations = params.MaximumIterations;
        optimizer.RelaxationFactor = params.RelaxationFactor;

        % Perform registration
        tform = imregtform(movingShell, ref2_down, fixedShell, ...
            ref1_down, 'affine', optimizer, metric, ...
            'PyramidLevels', params.PyramidLevel);
        registeredImage = imwarp(movingShell, ref2_down, tform, ...
            'OutputView', ref1_down);

        % Evaluate similarity using Dice coefficient
        overlap = 2 * nnz(fixedShell & registeredImage) / (nnz(fixedShell) + nnz(registeredImage));
        score = -overlap; % Minimize negative similarity
    catch
        % Assign a high penalty for failed registrations
        score = Inf;
    end
end