function [ref] = createRef2D(info, im, step)
    if nargin < 3
        step = 1;
    end

    adjustedPixelSpacing = info.PixelSpacing * step;

    ref = imref2d(size(im), ...
        adjustedPixelSpacing(1), ...
        adjustedPixelSpacing(2));
end