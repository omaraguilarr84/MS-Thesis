clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20240830_rev/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Crop Images
im1_cropped = im1(420:500, 200:300, 440);
im2_cropped = im2(420:500, 200:300, 440);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 500;
imBW1 = im1_cropped > threshold;
imBW2 = im2_cropped > threshold;

scale = 100;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

% step = 4;
% fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
% movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);
% 
% im1_down = im1(1:step:end, 1:step:end, 1:step:end);
% im2_down = im2(1:step:end, 1:step:end, 1:step:end);

%% Get References
shell = find(any(any(imBW1_double > 0, 1), 2));
fixedShell = imBW1_double(:, :, shell);
movingShell = imBW2_double(:, :, shell);
% 
% fRef = createRef3D(info1, fixedShell);
% mRef = createRef3D(info2, movingShell);

%% Registration
[optimizer, metric] = imregconfig('monomodal');
optimizer.GradientMagnitudeTolerance = 1e-3;
optimizer.MinimumStepLength = 1e-9;
optimizer.MaximumStepLength = 1e-4;
optimizer.MaximumIterations = 1000;
optimizer.RelaxationFactor = 0.6;

PyramidLevel = 3;
% registeredImage = imregister(movingShell, fixedShell, ...
%     'affine', optimizer, metric, ...
%     'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

tform = imregtform(movingShell, fixedShell, ...
    'similarity', optimizer, metric, ...
    'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

clc;
delete('optimization_log.txt');
diary('optimization_log.txt');

registeredImage = imwarp(movingShell, tform, 'OutputView', imref2d(size(fixedShell)));

diary off;

%% Evaluation Metric
% overlap = 2 * nnz(fixedShell & registeredImage) / (nnz(fixedShell) + nnz(registeredImage));
overlap = computeDice3D(fixedShell, registeredImage);
disp(['Dice Coefficient: ', num2str(overlap)]);

%% Visualize
figure;
imshowpair(fixedShell, registeredImage, 'Scaling', 'joint');

%% Interactive Visualization
% interactiveRegVis(registeredImage, fixedShell, 'z');