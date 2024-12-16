function [registeredImage] = regIms3D(movingImageFolder, ...
    fixedImageFolder, threshold, optimizer, metric)
    
    disp('Scanning images...');
    [fixedImage, fInfo] = loadDicom3D(fixedImageFolder);
    [movingImage, mInfo] = loadDicom3D(movingImageFolder);
    
    disp('Thresholding images...');
    fBW = fixedImage > threshold;
    mBW = movingImage > threshold;

    scale = 10;
    fBW = double(fBW) * scale;
    mBW = double(mBW) * scale;

    fRef = createRef(fInfo, fixedImage);
    mRef = createRef(mInfo, movingImage);

    clc;
    delete('optimization_log.txt');
    diary('optimization_log.txt');

    tform = imregtform(mBW, mRef, fBW, fRef, 'similarity', ...
        optimizer, metric, 'DisplayOptimization', true);

    diary off;

    plotOptimizationResults('optimization_log.txt');

    registeredImage = imwarp(mBW, mRef, tform, 'OutputView', fRef);
end

