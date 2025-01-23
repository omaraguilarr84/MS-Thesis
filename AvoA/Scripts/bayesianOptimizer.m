clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../AvoData/20240904/seriesFull/';
dicomFolder2 = '../AvoData/20240828/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Crop Images
% im1_cropped = im1(400:end, 200:300, :);
% im2_cropped = im2(400:end, 200:300, :);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 500;
imBW1 = im1 > threshold;
imBW2 = im2 > threshold;

im1_cropped = autoCrop3D(imBW1);
im2_cropped = autoCrop3D(imBW2);

scale = 1;

imBW1_double = double(im1_cropped) * scale;
imBW2_double = double(im2_cropped) * scale;

% step = 4;
% fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
% movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);
% 
% im1_down = im1(1:step:end, 1:step:end, 1:step:end);
% im2_down = im2(1:step:end, 1:step:end, 1:step:end);

%% Get References
shell = find(any(any(imBW2_double > 0, 1), 2));
fixedShell = imBW1_double(:, :, shell);
movingShell = imBW2_double(:, :, shell);

%% Bayesian Optimization with Improvements
disp('Starting Bayesian Optimization...');

n_workers = maxNumCompThreads;
pool = gcp('nocreate');
if isempty(pool)
    parpool('local', n_workers);
else
    if pool.NumWorkers ~= n_workers
        delete(pool);
        parpool('local', n_workers);
    end
end

% initialX = table( ...
%     1e-3, ...      % GradientMagnitudeTolerance
%     1e-9, ...    % MinimumStepLength
%     1e-2, ...     % MaximumStepLength
%     1000, ...       % MaximumIterations
%     0.6, ...       % RelaxationFactor
%     4, ...         % PyramidLevel
%     'VariableNames', {'GradientMagnitudeTolerance', 'MinimumStepLength', 'MaximumStepLength', ...
%                       'MaximumIterations', 'RelaxationFactor', 'PyramidLevel'});

results = bayesopt(@(params)objFcn(params, movingShell, fixedShell), ...
    [optimizableVariable('GradientMagnitudeTolerance', [1e-10, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MinimumStepLength', [1e-10, 1e-3], 'Transform', 'log'), ...
     optimizableVariable('MaximumStepLength', [1e-6, 1e-1], 'Transform', 'log'), ...
     optimizableVariable('MaximumIterations', [50, 1500], 'Type', 'integer'), ...
     optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
     optimizableVariable('PyramidLevel', [1, 5], 'Type', 'integer'), ...
     optimizableVariable('TransformType', {'similarity', 'affine'}, 'Type', 'categorical')], ...
    'Verbose', 1, ...
    'AcquisitionFunctionName', 'expected-improvement-plus', ...
    'MaxObjectiveEvaluations', 50, ...
    'UseParallel', true);

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
tformType = char(results.XAtMinObjective.TransformType);
tform = imregtform(movingShell, fixedShell, ...
    tformType, optimizer, metric, ...
    'PyramidLevels', bestPyramidLevel);

registeredImage = imwarp(movingShell, tform, 'linear', 'OutputView', ...
    imref3d(size(fixedShell)));

%% Evaluation of Shell Registration
interactiveRegVis(registeredImage, fixedShell, 'z');

overlap = computeDice3D(fixedShell, registeredImage);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage, fixedShell);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedShell, 1)^2 + size(fixedShell, 2)^2 + size(fixedShell, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

%% Apply shell tform to grayscale
regIm = imwarp(im2, tform, 'linear', 'OutputView', imref3d(size(im1)));

overlap = computeDice3D(im1, regIm);
disp(['Dice Coefficient: ', num2str(overlap)]);

interactiveRegVis(regIm, im1, 'z');

%% Register 2D Circle
threshold_circle = -1200;
imBW1_circle = double(im1 > threshold_circle);
imBW2_circle = double(im2 > threshold_circle);

fixedImage_circle = imBW1_circle(:, :, 1);
movingImage_circle = imBW2_circle(:, :, 1);

[optimizer_circle, metric_circle] = imregconfig('monomodal');

tform_circle = imregtform(movingImage_circle, fixedImage_circle, ...
    'similarity', optimizer_circle, metric_circle);

registeredImage_circle = imwarp(movingImage_circle, tform_circle, ...
    'linear', 'OutputView', imref2d(size(fixedImage_circle)));

overlap = computeDice3D(fixedImage_circle, registeredImage_circle);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage_circle, fixedImage_circle);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedImage_circle, 1)^2 + size(fixedImage_circle, 2)^2 + size(fixedImage_circle, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

%% Create New Transform and Apply
threshold_final = -500;
im1_final = im1 > threshold_final;
im2_final = im2 > threshold_final;

mat_final = eye(4);
for i = 1:2
    mat_final(i, i) = tform_circle.A(i, i);
end
mat_final(3, 3) = tform.A(3, 3);
mat_final(1:2, 4) = tform_circle.A(1:2, 3);

tform_final = affinetform3d(mat_final);

registeredImage_final = imwarp(im2_final, tform_final, 'linear', ...
    'OutputView', imref3d(size(im1_final)));

overlap = computeDice3D(im1_final, registeredImage_final);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage_final, im1_final);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(im1_final, 1)^2 + size(im1_final, 2)^2 + size(im1_final, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

interactiveRegVis(registeredImage_final, im1_final, 'z');

%% Apply to full grayscale
registeredImage_gray = imwarp(im2, tform_final, 'linear', ...
    'OutputView', imref3d(size(im1)));

overlap = computeDice3D(im1_final, registeredImage_final);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage_final, im1_final);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(im1_final, 1)^2 + size(im1_final, 2)^2 + size(im1_final, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

interactiveRegVis(registeredImage_gray, im1, 'z');

%% Objective Function Definition
function score = objFcn(params, movingShell, fixedShell)
    try
        tformType = char(params.TransformType);

        [optimizer, metric] = imregconfig('monomodal');
        optimizer.GradientMagnitudeTolerance = params.GradientMagnitudeTolerance;
        optimizer.MinimumStepLength = params.MinimumStepLength;
        optimizer.MaximumStepLength = params.MaximumStepLength;
        optimizer.MaximumIterations = params.MaximumIterations;
        optimizer.RelaxationFactor = params.RelaxationFactor;

        tform = imregtform(movingShell, fixedShell, ...
            tformType, optimizer, metric, ...
            'PyramidLevels', params.PyramidLevel);
        registeredImage = imwarp(movingShell, tform, 'linear', ...
            'OutputView', imref3d(size(fixedShell)));

        overlap = computeDice3D(fixedShell, registeredImage);
        score = -overlap;
    catch
        score = Inf;
    end
end