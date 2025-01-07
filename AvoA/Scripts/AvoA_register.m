clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20240830_rev/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Crop Images
im1_cropped = im1(400:500, 200:300, :);
im2_cropped = im2(400:500, 200:300, :);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 1200;
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
shell = find(any(any(imBW2_double > 0, 1), 2));
fixedShell = imBW1_double(:, :, shell);
movingShell = imBW2_double(:, :, shell);
% 
% fRef = createRef3D(info1, fixedShell);
% mRef = createRef3D(info2, movingShell);

% fRef = imref2d(size(fixedShell));
% mRef = imref2d(size(movingShell));

%% Registration
[optimizer, metric] = imregconfig('monomodal');
optimizer.GradientMagnitudeTolerance = 1e-3;
optimizer.MinimumStepLength = 1e-9;
optimizer.MaximumStepLength = 1e-2;
optimizer.MaximumIterations = 1000;
optimizer.RelaxationFactor = 0.6;

PyramidLevel = 4;
% registeredImage = imregister(movingShell, fixedShell, ...
%     'similarity', optimizer, metric, ...
%     'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

tform = imregtform(movingShell, fixedShell, ...
    'affine', optimizer, metric, ...
    'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

registeredImage = imwarp(movingShell, tform, 'OutputView', imref3d(size(fixedShell)));

% tform = imregcorr(movingShell, mRef, fixedShell, fRef, 'similarity', 'Window', true);
% 
% registeredImage = imwarp(movingShell, tform, 'OutputView', imref2d(size(fixedShell)));



%% Evaluation Metrics
% overlap = 2 * nnz(fixedShell & registeredImage) / (nnz(fixedShell) + nnz(registeredImage));
overlap = computeDice3D(fixedShell, registeredImage);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage, fixedShell);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedShell, 1)^2 + size(fixedShell, 2)^2 + size(fixedShell, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

%% Visualize
% figure;
% imshowpair(fixedShell, registeredImage, 'Scaling', 'joint');

%% Interactive Visualization
interactiveRegVis(registeredImage, fixedShell, 'z');