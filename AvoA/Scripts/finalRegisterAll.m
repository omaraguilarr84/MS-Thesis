clear; clc; close all;

%% Load in Fixed Point and Preprocess
dataFolder = '../Data/';
outputFolder = '../RegisteredData/';

subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

dates = {subfolders.name};
dates = sort(dates);

fixedDate = dates{1};
fixedPath = fullfile(dataFolder, fixedDate, 'series');
[fixedImage, fInfo] = loadDicom3D(fixedPath);

% Threshold where only the seashell is visible
threshold_shell = 500;
fixedImageBW = double(fixedImage > threshold_shell);

% Find slices where shell is visible
shellFixed = find(any(any(fixedImageBW > 0, 1), 2));

% If image z-dimension is backwards, reverse the image
if shellFixed(1) < 300
    fixedImageBW = fixedImageBW(:, :, end:-1:1);
    shellFixed = find(any(any(fixedImageBW > 0, 1), 2));
end

% Crop image in x, y, and z dimensions (z cropped to shell slices)
fixedImage_shell_full = fixedImageBW(:, :, shellFixed);
fixedImage_shell = autoCrop3D(fixedImage_shell_full);

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% Create table for evaluation report
scores = table('Size', [length(dates)-1, 4], ...
    'VariableTypes', {'string', 'double', 'double', 'double'}, ...
    'VariableNames', {'MovingDate', 'Dice', ...
    'HD', 'NormHD'});

%% Loop Through Dates (Images)
for i = 2:length(dates)
    fprintf('Registering %d of %d...\n', idx-1, length(dates)-1);
    
    % Load in moving image
    movingDate = dates{i};
    movingPath = fullfile(dataFolder, movingDate, 'series');
    [movingImage, mInfo] = loadDicom3D(movingPath);

    movingImageBW = double(movingImage > threshold_shell);
    
    shellMoving = find(any(any(movingImageBW > 0, 1), 2));

    if shellMoving(1) < 300
        movingImageBW = movingImageBW(:, :, end:-1:1);
    end

    movingImage_shell_full = movingImageBW(:, :, shellFixed);
    movingImage_shell = autoCrop3D(movingImage_shell_full);
    
    % Run Bayesian Optimizer to find best parameters for optimizer.
    % Transform type differs depending on the image, so affine and
    % similarity transforms are tested to compare results
    maxObjectiveEvals = 50;
    useParallel = true;
    results_affine = bayesianOptimizer3D(fixedImage_shell, movingImage_shell, ...
        maxObjectiveEvals, 'affine', useParallel);

    results_similarity = bayesianOptimizer3D(fixedImage_shell, movingImage_shell, ...
        maxObjectiveEvals, 'similarity', useParallel);

    if results_affine.MinObjective < results_similarity.MinObjective
        tformType = 'affine';
        results = results_affine;
    else
        tformType = 'similarity';
        results = results_similarity;
    end
    
    % Apply results of Bayesian Optimizer to cropped images
    [optimizer_shell, metric_shell] = imregconfig('monomodal');
    optimizer_shell.GradientMagnitudeTolerance = results.XAtMinObjective.GradientMagnitudeTolerance;
    optimizer_shell.MinimumStepLength = results.XAtMinObjective.MinimumStepLength;
    optimizer_shell.MaximumStepLength = results.XAtMinObjective.MaximumStepLength;
    optimizer_shell.MaximumIterations = results.XAtMinObjective.MaximumIterations;
    optimizer_shell.RelaxationFactor = results.XAtMinObjective.RelaxationFactor;
    pyrLevel = results.XAtMinObjective.PyramidLevel;

    tform_shell = imregtform(movingImage_shell, fixedImage_shell, ...
        tformType, optimizer_shell, metric_shell, 'PyramidLevels', ...
        pyrLevel);

    registeredImage_shell = imwarp(movingImage_shell, tform_shell, ... % do we really need these?
        'OutputView', imref3d(size(fixedImage_shell)));
    
    % Create new transform to obtain correct x and y translation and 
    % scale values. This uses a very low threshold to compute a 2D
    % registration of the circles apparent in the first slice.
    threshold_circle = -1200;
    fixedImage_circle = double(fixedImage > threshold_circle);
    movingImage_circle = double(movingImage > threshold_circle);

    fixedImage_circle = fixedImage_circle(:, :, 1);
    movingImage_circle = movingImage_circle(:, :, 1);

    [optimizer_circle, metric_circle] = imregconfig('monomodal');

    tform_circle = imregtform(movingImage_circle, fixedImage_circle, ...
        'similarity', optimizer_circle, metric_circle);

    registeredImage_circle = imwarp(movingImage_circle, tform_circle, ... % do we need this?
        'linear', 'OutputView', imref2d(size(fixedImage_circle)));
    
    % Make final transformation matrix
    mat_final = eye(4);
    for i = 1:2
        mat_final(i, i) = tform_circle.A(i, i);
        mat_final(i, 4) = tform_circle.A(i, 3);
    end
    mat_final(3, 3) = tform_shell.A(3, 3);

    tform_final = affinetform3d(mat_final);
    
    % Apply final transformation matrix to original grayscale images
    registeredImage_final = imwarp(movingImage, tform_final, 'linear', ...
        'OutputView', imref3d(fixedImage));
    
    % Log evaluation metrics in the table
    scores.MovingDate{i-1} = movingDate;
    scores.Dice(i-1) = computeDice3D(fixedImage, registeredImage_final);
    scores.HD(i-1) = computeHausdorffDistance(registeredImage_final, ...
        fixedImage);
    scores.NormHD(i-1) = scores.HD(i-1) / sqrt(size(fixedImage, 1)^2 + ...
        size(fixedImage, 2)^2 + size(fixedImage, 3)^2);
    
    % Save registered grayscale image to output folder
    outputFile = fullfile(outputFolder, sprintf('%s-%s.dcm', fixedDate, ...
        movingDate));
    dicomwrite(uint16(registeredImage_final), outputFile);
end
