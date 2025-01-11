clear; clc; close all;

%% Load Info and Image
dicomFolder1 = '../Data/20240910/series/';
dicomFolder2 = '../Data/20241007/series/';

warning('off', 'MATLAB:DELETE:Permission');

disp('Scanning Images...');
[im1, info1] = loadDicom3D(dicomFolder1);
[im2, info2] = loadDicom3D(dicomFolder2);

%% Crop Images
im1_cropped = im1(400:end, 200:300, :);
im2_cropped = im2(400:end, 200:300, :);

%% Threshold & Downsample Images
disp('Thresholding images...');
threshold = 500;
% threshold = 500;
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

fixedImage = imBW1_double(:, :, shell);
movingImage = imBW2_double(:, :, shell);

fixedImage_full = imBW1_double_full;
movingImage_full = imBW2_double_full;

% fRef = createRef3D(info1, fixedShell);
% mRef = createRef3D(info2, movingShell);

fRef = imref3d(size(fixedImage));
mRef = imref3d(size(movingImage));

%% Registration
[optimizer, metric] = imregconfig('monomodal');
optimizer.GradientMagnitudeTolerance = 1e-3;
optimizer.MinimumStepLength = 1e-9;
optimizer.MaximumStepLength = 1e-2; % 1e-2 for shell
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

%% Apply to Whole Image (Wrong)
registeredImageFull_wrong = imwarp(movingImage_full, tform, 'linear', 'OutputView', imref3d(size(fixedImage_full)));

overlap = computeDice3D(fixedImage_full, registeredImageFull_wrong);
disp(['Dice Coefficient (Full Wrong): ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImageFull_wrong, fixedImage_full);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedImage_full, 1)^2 + size(fixedImage_full, 2)^2 + size(fixedImage_full, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

interactiveRegVis(registeredImageFull_wrong, fixedImage_full, 'z');

%% Change tform
preTranslation = [1 0 0 -399;  % Adjust x offset
                  0 1 0 -199;  % Adjust y offset
                  0 0 1 0;     % No z offset
                  0 0 0 1];

% Translation back to the uncropped image space
postTranslation = [1 0 0 115;  % Reverse x offset
                   0 1 0 240;  % Reverse y offset
                   0 0 1 12;    % No z offset
                   0 0 0 1];

% adjustedMatrix = postTranslation * tform.A * preTranslation;
adjustedMatrix = tform.A * postTranslation;

tform_adjusted = affinetform3d(adjustedMatrix);

registeredImageFull = imwarp(movingImage_full, tform_adjusted, 'linear', 'OutputView', imref3d(size(fixedImage_full)));

overlap = computeDice3D(fixedImage_full, registeredImageFull);
disp(['Dice Coefficient (Full): ', num2str(overlap)]);

interactiveRegVis(registeredImageFull, fixedImage_full, 'z');

%% Manually change translation and scale values
mat_custom = [0.6801 0 0 0;
              0 0.6039 0 0;
              0 0 0.9786 0;
              0 0 0 1];

tform_custom = affinetform3d(mat_custom);

registeredImageFull_noThresh = imwarp(im2, tform_custom, 'linear', 'OutputView', imref3d(size(im1)));

overlap = computeDice3D(im1, registeredImageFull_noThresh);
disp(['Dice Coefficient (Raw): ', num2str(overlap)]);

interactiveRegVis(registeredImageFull_noThresh, im1, 'z');

%% Register circle to get translation values
threshold = -1200;
imBW1_trans = double(im1 > threshold);
imBW2_trans = double(im2 > threshold);

interactiveRegVis(imBW1_trans, imBW2_trans, 'z')
%% 0.9786

fixedImage_trans = imBW1_trans(:, :, 1);
movingImage_trans = imBW2_trans(:, :, 1);

[optimizer, metric] = imregconfig('monomodal');

tform_trans = imregtform(movingImage_trans, fixedImage_trans, ...
    'similarity', optimizer, metric);

registeredImage_trans = imwarp(movingImage_trans, tform_trans, ...
    'linear', 'OutputView', imref2d(size(fixedImage_trans)));

overlap = computeDice3D(fixedImage_trans, registeredImage_trans);
disp(['Dice Coefficient (Raw): ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImageFull_wrong, fixedImage_full);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(fixedImage_full, 1)^2 + size(fixedImage_full, 2)^2 + size(fixedImage_full, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

figure;
imshowpair(fixedImage_trans, registeredImage_trans, 'Scaling', 'joint');

%%
thresh = -500;
im1_thresh = im1 > thresh;
im2_thresh = im2 > thresh;

interactiveRegVis(im1_thresh, im2_thresh, 'z');

%%
tform_final = eye(4);
for i = 1:2
    tform_final(i, i) = tform_trans.A(i, i);
end
tform_final(3, 3) = tform.A(3, 3);

tform_final(1:2, 4) = tform_trans.A(1:2, 3);

tform_done = affinetform3d(tform_final);

registeredImage_final = imwarp(im2_thresh, tform_done, 'linear', ...
    'OutputView', imref3d(size(im1_thresh)));

overlap = computeDice3D(im1_thresh, registeredImage_final);
disp(['Dice Coefficient (Raw): ', num2str(overlap)]);

hd = computeHausdorffDistance(registeredImage_final, im1_thresh);
disp(['Haussdorff Distance: ', num2str(hd)]);

norm_hd = hd / sqrt(size(im1_thresh, 1)^2 + size(im1_thresh, 2)^2 + ...
    size(im1_thresh, 3)^2);
disp(['Normalized HD: ', num2str(norm_hd)]);

interactiveRegVis(registeredImage_final, im1_thresh, 'z');