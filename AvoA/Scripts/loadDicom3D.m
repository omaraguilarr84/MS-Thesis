function [im, info] = loadDicom3D(imFolderPath)
    dicomFolder = imFolderPath;
    
    files = dir(fullfile(dicomFolder, '*.dcm'));
    
    scan = [];
    for i = 1:length(files)
        slice = dicomread(fullfile(files(i).folder, files(i).name));
        scan(:, :, i) = slice;
    end

    info = dicominfo(fullfile(files(1).folder, files(1).name));
    im = info.RescaleSlope * scan + info.RescaleIntercept;
end