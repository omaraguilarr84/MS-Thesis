clear; clc; close all;

%% load
fixedPath = '../AvoData/20240919_2/seriesFull';
movingPath = '../AvoData/20240718_2/series';

[fixedImage, fInfo] = loadDicom3D(fixedPath);
[movingImage, mInfo] = loadDicom3D(movingPath);
%%
fRef = createRef(fInfo, fixedImage);
mRef = createRef(mInfo, movingImage);
%%
threshold_shell = 1500;
fixedImageBW = double(fixedImage > threshold_shell);
movingImageBW = double(movingImage > threshold_shell);

shellFixed = find(any(any(fixedImageBW > 0, 1), 2));
shellMoving = find(any(any(movingImageBW > 0, 1), 2));

if shellFixed(1) < 300
    fixedImage = fixedImage(:, :, end:-1:1);
    fixedImageBW = fixedImageBW(:, :, end:-1:1);
    shellFixed = find(any(any(fixedImageBW < 0, 1), 2));
end

if shellMoving(1) < 300
    movingImage = movingImage(:, :, end:-1:1);
    movingImageBW = movingImageBW(:, :, end:-1:1);
    shellMoving = find(any(any(movingImageBW < 0, 1), 2));
end

fixedImage_shell_full = fixedImageBW(:, :, shellFixed);
movingImage_shell_full = movingImageBW(:, :, shellFixed);

fixedImage_shell = autoCrop3D(fixedImage_shell_full);
movingImage_shell = autoCrop3D(movingImage_shell_full);

maxObjectiveEvals = 200;
useParallel = true;
results = bayesianOptimizer3DwithRef(fixedImage_shell, fRef, movingImage_shell, ...
    mRef, maxObjectiveEvals, useParallel);

%%

[optimizer_shell, metric_shell] = imregconfig('monomodal');
optimizer_shell.GradientMagnitudeTolerance = results.XAtMinObjective.GradientMagnitudeTolerance;
optimizer_shell.MinimumStepLength = results.XAtMinObjective.MinimumStepLength;
optimizer_shell.MaximumStepLength = results.XAtMinObjective.MaximumStepLength;
optimizer_shell.MaximumIterations = results.XAtMinObjective.MaximumIterations;
optimizer_shell.RelaxationFactor = results.XAtMinObjective.RelaxationFactor;
pyLevel = results.XAtMinObjective.PyramidLevel;
tformType = char(results.XAtMinObjective.TransformType);

tform_shell = imregtform(movingImage_shell, mRef, fixedImage_shell, ...
    fRef, tformType, optimizer_shell, metric_shell, 'PyramidLevels', ...
    pyrLevel);

registeredImage_shell = imwarp(movingImage_shell, mRef, tform_shell, ...
    'linear', 'OutputView', fRef);

