function hd = computeHausdorffDistance(binaryImage1, binaryImage2)
    % Ensure inputs are logical
    binaryImage1 = logical(binaryImage1);
    binaryImage2 = logical(binaryImage2);
    
    D1 = bwdist(binaryImage1);
    D2 = bwdist(binaryImage2);
    
    hd1 = max(D2(binaryImage1));
    hd2 = max(D1(binaryImage2));
    
    hd = max(hd1, hd2);
end
