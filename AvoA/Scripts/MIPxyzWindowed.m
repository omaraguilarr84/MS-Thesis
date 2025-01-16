function MIP = MIPxyzWindowed(IM, windowRange, showFigure)
    if nargin < 3
        showFigure = false;
    end

    % Compute MIPs for z, x, and y directions
    MIP.z = max(IM, [], 3);
    MIP.x = squeeze(max(IM, [], 2));
    MIP.y = squeeze(max(IM, [], 1));
    
    % Create a blank area for tiling
    tmp = zeros(size(IM, 3), class(IM));
    
    % Apply the window range to each MIP
    MIP.z = applyWindowRange(MIP.z, windowRange);
    MIP.x = applyWindowRange(MIP.x, windowRange);
    MIP.y = applyWindowRange(MIP.y, windowRange);
    
    % Create the tiled MIP visualization
    MIP.tile = [
        MIP.z, fliplr(MIP.x)
        flipud(transpose(MIP.y)), tmp
    ];
    
    % Optionally show the figure
    if showFigure
        figure(1); imagesc(MIP.tile, windowRange); axis image; colormap gray;
    end
end

function adjustedIM = applyWindowRange(IM, windowRange)
    % Scale the input image to fit within the window range
    minVal = windowRange(1);
    maxVal = windowRange(2);
    
    % Clamp values outside the window range
    adjustedIM = max(min(IM, maxVal), minVal);
end
