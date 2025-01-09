clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20240830_rev/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Crop Images
im1_cropped = im1(400:512, 200:300, :);
im2_cropped = im2(400:512, 200:300, :);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 1500;
imBW1 = im1_cropped > threshold;
imBW2 = im2_cropped > threshold;

imBW1_full = im1 > threshold;
imBW2_full = im2 > threshold;

% imBW1 = im1 > threshold;
% imBW2 = im2 > threshold;

scale = 1;

imBW1_double = double(imBW1) * scale;
imBW2_double = double(imBW2) * scale;

imBW1_double_full = double(imBW1_full) * scale;
imBW2_double_full = double(imBW2_full) * scale;

% step = 4;
% fixedImageBW_down = imBW1_double(1:step:end, 1:step:end, 1:step:end);
% movingImageBW_down = imBW2_double(1:step:end, 1:step:end, 1:step:end);
% 
% im1_down = im1(1:step:end, 1:step:end, 1:step:end);
% im2_down = im2(1:step:end, 1:step:end, 1:step:end);

%% Get References
shell = find(any(any(imBW2_double > 0, 1), 2));
% fixedShell = imBW1_double(:, :, shell); % shouldn't be doing this
% movingShell = imBW2_double(:, :, shell);

% fixedShell = imBW1_double;
% movingShell = imBW2_double;

fixedImage = imBW1_double(:, :, :);
movingImage = imBW2_double(:, :, :);

% fixedShell = imBW1_double(:, :, :);
% movingShell = imBW2_double(:, :, :);

% fRef = createRef3D(info1, fixedShell);
% mRef = createRef3D(info2, movingShell);

fRef = imref3d(size(fixedImage));
mRef = imref3d(size(movingImage));

%% Registration
[optimizer, metric] = imregconfig('monomodal');
optimizer.GradientMagnitudeTolerance = 1e-3;
optimizer.MinimumStepLength = 1e-9;
optimizer.MaximumStepLength = 1e-4;
optimizer.MaximumIterations = 1000;
optimizer.RelaxationFactor = 0.6;

PyramidLevel = 4;
% registeredImage = imregister(movingShell, fixedShell, ...
%     'similarity', optimizer, metric, ...
%     'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

tform = imregtform(movingImage, fixedImage, ...
    'affine', optimizer, metric, ...
    'PyramidLevels', PyramidLevel, 'DisplayOptimization', true);

registeredImage = imwarp(movingImage, tform, 'linear', 'OutputView', fRef);

% tform = imregcorr(movingShell, mRef, fixedShell, fRef, 'similarity', 'Window', true);
% 
% registeredImage = imwarp(movingShell, tform, 'OutputView', imref2d(size(fixedShell)));



%% Evaluation Metrics
% overlap = 2 * nnz(fixedShell & registeredImage) / (nnz(fixedShell) + nnz(registeredImage));
overlap = computeDice3D(fixedImage, registeredImage);
disp(['Dice Coefficient: ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage, fixedImage);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedImage, 1)^2 + size(fixedImage, 2)^2 + size(fixedImage, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

%% Visualize
% figure;
% imshowpair(fixedShell, registeredImage, 'Scaling', 'joint');

%% Interactive Visualization
interactiveRegVis(registeredImage, fixedImage, 'z');

%% Apply to Whole Image
registeredImageFull = imwarp(movingShellFull, tform, 'linear', 'OutputView', imref3d(size(fixedImage)));
% 
interactiveRegVis(registeredImageFull, fixedImage, 'z');
overlap = computeDice3D(fixedImage, registeredImageFull);
disp(['Dice Coefficient (Full): ', num2str(overlap)]);
