clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20241007/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 500;
imBW1 = im1 > threshold;
imBW2 = im2 > threshold;

scale = 10;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

step = 4;
fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);

im1_down = im1(1:step:end, 1:step:end, 1:step:end);
im2_down = im2(1:step:end, 1:step:end, 1:step:end);

%% Get References
shell = find(any(any(fixedImageBW_down > 0, 1), 2));
fixedShell = fixedImageBW_down(:, :, shell);
movingShell = movingImageBW_down(:, :, shell);

fRef = createRef(info1, fixedShell, step);
mRef = createRef(info2, movingShell, step);

%% Bayesian Optimization with Improvements
disp('Starting Bayesian Optimization...');

n_workers = 4;
pool = gcp('nocreate');
if isempty(pool)
    parpool('local', n_workers);
else
    if pool.NumWorkers ~= n_workers
        delete(pool);
        parpool('local', n_workers);
    end
end

initialX = table( ...
    1e-6, ...      % GradientMagnitudeTolerance
    1e-4, ...    % MinimumStepLength
    6.25e-3, ...     % MaximumStepLength
    300, ...       % MaximumIterations
    0.6, ...       % RelaxationFactor
    2, ...         % PyramidLevel
    'VariableNames', {'GradientMagnitudeTolerance', 'MinimumStepLength', 'MaximumStepLength', ...
                      'MaximumIterations', 'RelaxationFactor', 'PyramidLevel'});

results = bayesopt(@(params)objFcn(params, movingShell, mRef, fixedShell, fRef), ...
    [optimizableVariable('GradientMagnitudeTolerance', [1e-10, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MinimumStepLength', [1e-10, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MaximumStepLength', [1e-6, 1e-1], 'Transform', 'log'), ...
     optimizableVariable('MaximumIterations', [50, 300], 'Type', 'integer'), ...
     optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
     optimizableVariable('PyramidLevel', [1, 3], 'Type', 'integer')], ...
    'Verbose', 1, ...
    'AcquisitionFunctionName', 'expected-improvement-plus', ...
    'MaxObjectiveEvaluations', 200, ...
    'UseParallel', true);
    %'InitialX', initialX);

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

bestPyramidLevel = results.XAtMinObjective.PyramidLevel;
tform = imregtform(movingShell, mRef, fixedShell, ...
    fRef, 'affine', optimizer, metric, ...
    'PyramidLevels', bestPyramidLevel);

registeredImage = imwarp(movingShell, mRef, tform, 'OutputView', fRef);

interactiveRegVis(registeredImage, fixedShell, 'z');

%% Objective Function Definition
function score = objFcn(params, movingShell, mRef, fixedShell, fRef)
    try
        [optimizer, metric] = imregconfig('monomodal');
        optimizer.GradientMagnitudeTolerance = params.GradientMagnitudeTolerance;
        optimizer.MinimumStepLength = params.MinimumStepLength;
        optimizer.MaximumStepLength = params.MaximumStepLength;
        optimizer.MaximumIterations = params.MaximumIterations;
        optimizer.RelaxationFactor = params.RelaxationFactor;

        tform = imregtform(movingShell, mRef, fixedShell, ...
            fRef, 'affine', optimizer, metric, ...
            'PyramidLevels', params.PyramidLevel);
        registeredImage = imwarp(movingShell, mRef, tform, ...
            'OutputView', fRef);

        overlap = 2 * nnz(fixedShell & registeredImage) / (nnz(fixedShell) + nnz(registeredImage));
        score = -overlap;
    catch
        score = Inf;
    end
end