function [ref] = createRef(info, im, step)
    if nargin < 3
        step = 1;
    end

    adjustedPixelSpacing = info.PixelSpacing * step;
    adjustedSliceThickness = info.SliceThickness * step;

    ref = imref3d(size(im), ...
        adjustedPixelSpacing(1), ...
        adjustedPixelSpacing(2), ...
        adjustedSliceThickness);
end