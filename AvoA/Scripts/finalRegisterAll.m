clear; clc; close all;

%% Load in Fixed Point and Preprocess
dataFolder = '../AvoData/';
outputFolder = '../RegisteredData/';

subfolders = dir(dataFolder);
subfolders = subfolders([subfolders.isdir]);
subfolders = subfolders(~ismember({subfolders.name}, {'.', '..'}));

dates = {subfolders.name};
dates = sort(dates);

fixedDate = '20240919_2';
fixedPath = fullfile(dataFolder, fixedDate, 'seriesFull');
[fixedImage, fInfo] = loadDicom3D(fixedPath);

% Threshold where only the seashell is visible
threshold_shell = 1500;
fixedImageBW = double(fixedImage > threshold_shell);

% Find slices where shell is visible
shellFixed = find(any(any(fixedImageBW > 0, 1), 2));

% If image z-dimension is backwards, reverse the image
if shellFixed(1) < 300
    fixedImage = fixedImage(:, :, end:-1:1);
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
% scores = table('Size', [0, 4], ...
%     'VariableTypes', {'string', 'double', 'double', 'double'}, ...
%     'VariableNames', {'MovingDate', 'Dice', 'HD', 'NormHD'});

% Establish window level for MIPs
windowLevel = [800 1300];

%% Loop Through Dates (Images)
for i = 1:length(dates)
    fprintf('Registering %d of %d...\n', i, length(dates));

    currentFolder = fullfile(dataFolder, dates{i});
    
    % Load in moving image
    movingDate = dates{i};
    if strcmp(movingDate, fixedDate)
        fixedMIP = MIPxyzWindowed(fixedImage, windowLevel, false);
        MIPImages = cat(3, MIPImages, fixedMIP.tile);

        frameDates{end + 1} = {fixedDate};
        fovSizes{end + 1} = {'large'};
        continue
    elseif endsWith(movingDate, '_bad')
        continue
    end

    series = fullfile(dataFolder, movingDate, 'series');
    seriesFull = fullfile(dataFolder, movingDate, 'seriesFull');

    subDirs = dir(currentFolder);
    subDirs = subDirs([subDirs.isdir]);
    subDirs = subDirs(~ismember({subDirs.name}, {'.', '..'}));

    for l = 1:length(subDirs)
        seriesFolder = fullfile(currentFolder, subDirs(l).name);

        if strcmp(seriesFolder, series) && ~exist(seriesFull, 'dir')
            movingPath = series;
            fov = 'small';
        elseif strcmp(seriesFolder, seriesFull)
            movingPath = seriesFull;
            fov = 'large';
        else
            continue
        end

        [movingImage, mInfo] = loadDicom3D(movingPath);
    
        movingImageBW = double(movingImage > threshold_shell);
        
        shellMoving = find(any(any(movingImageBW > 0, 1), 2));
    
        if shellMoving(1) < 300
            movingImage = movingImage(:, :, end:-1:1);
            movingImageBW = movingImageBW(:, :, end:-1:1);
        end
    
        movingImage_shell_full = movingImageBW(:, :, shellFixed);
        movingImage_shell = autoCrop3D(movingImage_shell_full);
        
        % Run Bayesian Optimizer to find best parameters for optimizer
        maxObjectiveEvals = 50;
        useParallel = true;
        minObj = 0;
        cnt = 0;
        while minObj > -0.9 || cnt < 5
            results = bayesianOptimizer3D(fixedImage_shell, movingImage_shell, ...
                maxObjectiveEvals, useParallel);
            minObj = results.MinObjective;
            cnt = cnt + 1;
        end
    
        % Apply results of Bayesian Optimizer to cropped images
        [optimizer_shell, metric_shell] = imregconfig('monomodal');
        optimizer_shell.GradientMagnitudeTolerance = results.XAtMinObjective.GradientMagnitudeTolerance;
        optimizer_shell.MinimumStepLength = results.XAtMinObjective.MinimumStepLength;
        optimizer_shell.MaximumStepLength = results.XAtMinObjective.MaximumStepLength;
        optimizer_shell.MaximumIterations = results.XAtMinObjective.MaximumIterations;
        optimizer_shell.RelaxationFactor = results.XAtMinObjective.RelaxationFactor;
        pyrLevel = results.XAtMinObjective.PyramidLevel;
        tformType = char(results.XAtMinObjective.TransformType);
    
        tform_shell = imregtform(movingImage_shell, fixedImage_shell, ...
            tformType, optimizer_shell, metric_shell, 'PyramidLevels', ...
            pyrLevel);
    
        registeredImage_shell = imwarp(movingImage_shell, tform_shell, ... % do we really need these?
            'OutputView', imref3d(size(fixedImage_shell)));
    
        overlap_shell = computeDice3D(registeredImage_shell, fixedImage_shell);
        disp(['Dice Coefficient (Shell): ', num2str(overlap_shell)]);
        
        % Create new transform to obtain correct x and y translation and 
        % scale values. This uses a very low threshold to compute a 2D
        % registration of the circles apparent in the first slice.
        threshold_circle = -200;
        fixedImage_circle = double(fixedImage > threshold_circle);
        movingImage_circle = double(movingImage > threshold_circle);
    
        fixedImage_circle = fixedImage_circle(:, :, 1);
        movingImage_circle = movingImage_circle(:, :, 1);
        
        % Bayesian optimizer for 2D circle images
        minObj_circle = 0;
        cnt = 0;
        while minObj_circle > -0.98 || cnt < 5
            results_circle = bayesianOptimizer2D(fixedImage_circle, movingImage_circle, ...
                200, useParallel, 'shell');
            minObj_circle = results_circle.MinObjective;
            cnt = cnt + 1;
        end
    
        % Apply results to circle images
        [optimizer_circle, metric_circle] = imregconfig('monomodal');
        optimizer_circle.GradientMagnitudeTolerance = results_circle.XAtMinObjective.GradientMagnitudeTolerance;
        optimizer_circle.MinimumStepLength = results_circle.XAtMinObjective.MinimumStepLength;
        optimizer_circle.MaximumStepLength = results_circle.XAtMinObjective.MaximumStepLength;
        optimizer_circle.MaximumIterations = results_circle.XAtMinObjective.MaximumIterations;
        optimizer_circle.RelaxationFactor = results_circle.XAtMinObjective.RelaxationFactor;
        pyrLevel_circle = results_circle.XAtMinObjective.PyramidLevel;
        tformType_circle = char(results_circle.XAtMinObjective.TransformType);
    
        tform_circle = imregtform(movingImage_circle, fixedImage_circle, ...
            tformType_circle, optimizer_circle, metric_circle, ...
            'PyramidLevels', pyrLevel_circle);
    
        registeredImage_circle = imwarp(movingImage_circle, tform_circle, ... % do we need this?
            'linear', 'OutputView', imref2d(size(fixedImage_circle)));

        overlap_circle = computeDice3D(registeredImage_circle, fixedImage_circle);
        disp(['Dice Coefficient (Circle): ', num2str(overlap_circle)]);
        
        % Make final transformation matrix
        fixedPixelSpacing = fInfo.PixelSpacing(1);
        movingPixelSpacing = mInfo.PixelSpacing(1);
        pixelSpacingRatio = movingPixelSpacing / fixedPixelSpacing;
        y_bottom = pixelSpacingRatio * 512;

        mat_mid = [pixelSpacingRatio 0 0 tform_circle.A(1, 3);
                    0 pixelSpacingRatio 0 512 - y_bottom;
                    0 0 tform_shell.A(3, 3) 0;
                    0 0 0 1];

        tform_mid = affinetform3d(mat_mid);

        registeredImage_mid = imwarp(movingImage, tform_mid, 'linear', ...
            'OutputView', imref3d(size(fixedImage)));

        threshold_mid = 100;
        fixedImage_mid = double(fixedImage(:, :, 256) > threshold_mid);
        movingImage_mid = double(registeredImage_mid(:, :, 256) > threshold_mid);

        overlap_mid = computeDice3D(movingImage_mid, fixedImage_mid);
        disp(['Dice Coefficient (Mid): ', num2str(overlap_mid)]);

        fixedImage_mid(1:200, :) = 0;
        
        minObj_mid = 0;
        cnt = 0;
        while minObj_mid > -0.9 || cnt < 5
            results_mid = bayesianOptimizer2D(fixedImage_mid, movingImage_mid, ...
                50, true, 'mid');
            minObj_mid = results_mid.MinObjective;
            cnt = cnt + 1;
        end

        [optimizer_mid, metric_mid] = imregconfig('monomodal');
        optimizer_mid.GradientMagnitudeTolerance = results_mid.XAtMinObjective.GradientMagnitudeTolerance;
        optimizer_mid.MinimumStepLength = results_mid.XAtMinObjective.MinimumStepLength;
        optimizer_mid.MaximumStepLength = results_mid.XAtMinObjective.MaximumStepLength;
        optimizer_mid.MaximumIterations = results_mid.XAtMinObjective.MaximumIterations;
        optimizer_mid.RelaxationFactor = results_mid.XAtMinObjective.RelaxationFactor;
        pyrLevel_mid = results_mid.XAtMinObjective.PyramidLevel;
        
        tform_adj = imregtform(movingImage_mid, fixedImage_mid, 'translation', ...
            optimizer_mid, metric_mid, 'PyramidLevels', pyrLevel_mid);
        
        registeredImage_adj = imwarp(movingImage_mid, tform_adj, 'linear', ...
            'OutputView', imref2d(size(fixedImage_mid)));

        overlap_adj = computeDice3D(registeredImage_adj, fixedImage_mid);
        disp(['Dice Coefficient (Adj): ', num2str(overlap_adj)]);

        tform_final = tform_mid;
        tform_final.A(1, 4) = tform_mid.A(1, 4) + tform_adj.A(1, 3);
        tform_final.A(2, 4) = tform_mid.A(2, 4) + tform_adj.A(2, 3);
        
        registeredImage_final = imwarp(movingImage, tform_final, 'linear', 'OutputView', ...
            imref3d(size(fixedImage)));

        overlap_final = computeDice3D(registeredImage_final, fixedImage);
        disp(['Dice Coefficient (Final): ', num2str(overlap_final)]);

        if overlap_final == 0
            continue
        end
        
        % Save registered grayscale image to output folder
        outputFile = fullfile(outputFolder, sprintf('%s-%s', fixedDate, ...
            movingDate), fov);
    
        if ~exist(outputFile, 'dir')
            mkdir(outputFile);
        end
        
        seriesUID = dicomuid;
        for k = 1:size(registeredImage_final, 3)
            outputSlice = fullfile(outputFile, sprintf('IM-%04d.dcm', k));
            
            sliceInfo = mInfo;
            sliceInfo.InstanceNumber = k; % need to ask about this
            sliceInfo.SeriesInstanceUID = seriesUID;
    
            dicomwrite(uint16(registeredImage_final(:, :, k)), outputSlice, sliceInfo);
        end
        
        if i == 1
            % Initialize MIP stack
            registeredMIP = MIPxyzWindowed(registeredImage_final, windowLevel, false);
            MIPImages = registeredMIP.tile;

            frameDates{1} = dates{i};
            fovSizes{1} = fov;

            % Initialize evaluation table
            Date(1, 1) = string(dates{i});
            FOV(1, 1) = string(fov);
            Dice(1, 1) = computeDice3D(fixedImage, registeredImage_final);
            HD(1, 1) = computeHausdorffDistance(registeredImage_final, ...
                fixedImage);
            NormHD(1, 1) = HD(1) / sqrt(size(fixedImage, 1)^2 + ...
                size(fixedImage, 2)^2 + size(fixedImage, 3)^2);
        else
            % Add to MIP stack
            registeredMIP = MIPxyzWindowed(registeredImage_final, windowLevel, false);
            MIPImages = cat(3, MIPImages, registeredMIP.tile);

            frameDates{end + 1} = dates{i};
            fovSizes{end + 1} = fov;

            % Add to evaluation table
            Date(end + 1, 1) = string(dates{i});
            FOV(end + 1, 1) = string(fov);
            Dice(end + 1, 1) = computeDice3D(fixedImage, registeredImage_final);
            HD(end + 1, 1) = computeHausdorffDistance(registeredImage_final, ...
                fixedImage);
            NormHD(end + 1, 1) = HD(end) / sqrt(size(fixedImage, 1)^2 + ...
                size(fixedImage, 2)^2 + size(fixedImage, 3)^2);
        end
    end
end

% Create evaluation table
scores = table(Date, Dice, HD, NormHD);

% Create time lapse
MIPxyzLapse(MIPImages, frameDates, fovSizes);

%% Save Video
saveMIPLapseVideo(MIPImages, '../MIP_Videos/Avo_MIP_TL_all.mp4', 3, frameDates, fovSizes);

%%
fixedImage_dot = fixedImage(:, :, 1);
movingImage_dot = movingImage(:, :, 1);

fixedImage_dot(500:512, 250:260) = 10000;
movingImage_dot(500:512, 250:260) = 10000;

threshold_dot = 9000;
fixedImageBW_dot = double(fixedImage_dot > threshold_dot);
movingImageBW_dot = double(movingImage_dot > threshold_dot);

[optimizer_dot, metric_dot] = imregconfig('monomodal');

tform_dot = imregtform(movingImageBW_dot, fixedImageBW_dot, ...
    'similarity', optimizer_circle, metric_circle);

registeredImage_dot = imwarp(movingImageBW_dot, tform_dot, 'linear', ...
    'OutputView', imref2d(size(fixedImageBW_dot)));

overlap_final = computeDice3D(registeredImage_dot, fixedImageBW_dot);
disp(['Dice Coefficient: ', num2str(overlap_final)]);

%%
mat = [0.4698 0 0 135.9961;
        0 0.4698 0 185.2481;
        0 0 0.9961 0;
        0 0 0 1];

tform = affinetform3d(mat);

regIm = imwarp(movingImage, tform, 'linear', 'OutputView', ...
    imref3d(size(fixedImage)));

computeDice3D(regIm, fixedImage)

%%
interactiveRegVis(regIm, fixedImage, 'z');

%%
projectionXY = any(fixedImage_shell_full, 3);
    
[rows, cols] = find(projectionXY);
xMin = min(rows) - 50;
yMin = min(cols) - 50;
yMax = max(cols) + 50;
    
croppedImage = fixedImage_shell_full(xMin:end, yMin:yMax, :);

%%
mat = [0.4698 0 0 135.9961;
        0 0.4698 0 283;
        0 0 0.9961 0;
        0 0 0 1];

tform = affinetform3d(mat);

regIm = imwarp(movingImage, tform, 'linear', 'OutputView', ...
    imref3d(size(fixedImage)));

computeDice3D(regIm, fixedImage)

%%
interactiveRegVis(regIm, fixedImage, 'z');

%%
fixedPixelSpacing = fInfo.PixelSpacing(1);
movingPixelSpacing = mInfo.PixelSpacing(1);
pixelSpacingRatio = movingPixelSpacing / fixedPixelSpacing;
y_bottom = pixelSpacingRatio * 512;

tform_idk = tform_final;
tform_idk.A(2, 4) = 512 - y_bottom;

registeredImage_idk = imwarp(movingImage, tform_idk, 'linear', ...
    'OutputView', imref3d(size(fixedImage)));

fixedImage_mid = double(fixedImage(:, :, 256) > 100);
movingImage_mid = double(registeredImage_idk(:, :, 256) > 100);

fixedImage_mid(1:200, :) = 0;

% imshowpair(fixedImage_mid, movingImage_mid);

results_mid = bayesianOptimizer2D(fixedImage_mid, movingImage_mid, 50, true, 'mid');

[optimizer_mid, metric_mid] = imregconfig('monomodal');
optimizer_mid.GradientMagnitudeTolerance = results_mid.XAtMinObjective.GradientMagnitudeTolerance;
optimizer_mid.MinimumStepLength = results_mid.XAtMinObjective.MinimumStepLength;
optimizer_mid.MaximumStepLength = results_mid.XAtMinObjective.MaximumStepLength;
optimizer_mid.MaximumIterations = results_mid.XAtMinObjective.MaximumIterations;
optimizer_mid.RelaxationFactor = results_mid.XAtMinObjective.RelaxationFactor;
pyrLevel_mid = results_mid.XAtMinObjective.PyramidLevel;
%tformType_mid = char(results_mid.XAtMinObjective.TransformType);

tform_mid = imregtform(movingImage_mid, fixedImage_mid, 'translation', ...
    optimizer_mid, metric_mid, 'PyramidLevels', pyrLevel_mid);

registeredImage_mid = imwarp(movingImage_mid, tform_mid, 'linear', ...
    'OutputView', imref2d(size(fixedImage_mid)));

computeDice3D(registeredImage_mid, fixedImage_mid);

imshowpair(registeredImage_mid, fixedImage_mid);

%%
mat = [pixelSpacingRatio 0 0 tform_idk.A(1, 4) + tform_mid.A(1, 3);
        0 pixelSpacingRatio 0 tform_idk.A(2, 4) + tform_mid.A(2, 3);
        0 0 tform_final.A(3, 3) 0;
        0 0 0 1];

tform = affinetform3d(mat);

registeredImage = imwarp(movingImage, tform, 'linear', 'OutputView', ...
    imref3d(size(fixedImage)));

interactiveRegVis(registeredImage, fixedImage, 'z');

%% reset final to have 0 y tranlastion and then see if it gets it right