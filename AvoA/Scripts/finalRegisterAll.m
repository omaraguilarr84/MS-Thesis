clear; clc; close all;

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

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

scores = table('Size', [length(dates)-1, 4], ...
    'VariableTypes', {'string', 'double', 'double', 'double'}, ...
    'VariableNames', {'MovingDate', 'Dice', ...
    'HD', 'NormHD'});

for i = 2:length(dates)
    fprintf('Registering %d of %d...\n', idx-1, length(dates)-1);

    movingDate = dates{i};
    movingPath = fullfile(dataFolder, movingDate, 'series');
    [movingImage, mInfo] = loadDicom3D(movingPath);
    
    maxObjectiveEvals = 100;
    useParallel = true;
    results = bayesianOptimizer3D(fixedImage, movingImage, ...
        maxObjectiveEvals, useParallel);

    [optimizer, metric] = imregconfig('monomodal');
    optimizer.GradientMagnitudeTolerance = results.XAtMinObjective.GradientMagnitudeTolerance;
    optimizer.MinimumStepLength = results.XAtMinObjective.MinimumStepLength;
    optimizer.MaximumStepLength = results.XAtMinObjective.MaximumStepLength;
    optimizer.MaximumIterations = results.XAtMinObjective.MaximumIterations;
    optimizer.RelaxationFactor = results.XAtMinObjective.RelaxationFactor;
    pyrLevel = results.XAtMinObjective.PyramidLevel;

    tform = imregtform(movingImage, fixedImage, 'affine', ...
        optimizer, metric, 'PyramidLevels', pyrLevel);

    registeredImage = imwarp(movingImage, tform, 'OutputView', ...
        imref3d(size(fixedImage)));

    scores.MovingDate{i-1} = movingDate;
    scores.Dice(i-1) = computeDice3D(fixedImage, registeredImage);
    scores.HD(i-1) = computeHausdorffDistance(registeredImage, fixedImage);
    scores.NormHD(i-1) = scores.HD(i-1) / sqrt(size(fixedShell, 1)^2 + ...
        size(fixedShell, 2)^2 + size(fixedShell, 3)^2);

    outputFile = fullfile(outputFolder, sprintf('%s-%s.dcm', fixedDate, movingDate));
    dicomwrite(uint16(registeredImage), outputFile);
end

