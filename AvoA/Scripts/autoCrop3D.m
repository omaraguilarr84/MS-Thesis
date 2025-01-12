function croppedImage = autoCrop3D(im)
    projectionXY = any(im, 3);
    
    [rows, cols] = find(projectionXY);
    xMin = min(rows) - 50;
    yMin = min(cols) - 50;
    yMax = max(cols) + 50;
    
    croppedImage = im(xMin:end, yMin:yMax, :);
end