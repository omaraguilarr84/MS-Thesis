function MIP = MIPxyzOverlay(IM1, IM2, alpha)
    if ~isequal(size(IM1), size(IM2))
        error('Input images must be the same size.');
    end

    if nargin < 3
        alpha = 0.5;
    end

    MIP1.z = max(IM1, [], 3);
    MIP1.x = squeeze(max(IM1, [], 2));
    MIP1.y = squeeze(max(IM1, [], 1));

    MIP2.z = max(IM2, [], 3);
    MIP2.x = squeeze(max(IM2, [], 2));
    MIP2.y = squeeze(max(IM2, [], 1));

    MIP.z = alpha * MIP1.z + (1 - alpha) * MIP2.z;
    MIP.x = alpha * MIP1.x + (1 - alpha) * MIP2.x;
    MIP.y = alpha * MIP1.y + (1 - alpha) * MIP2.y;

    tmp = zeros(size(IM1, 3), class(IM1));

    MIP.tile = [
        MIP.z, fliplr(MIP.x);
        flipud(transpose(MIP.y)), tmp
        ];

    figure(1);
    imagesc(MIP.tile);
    axis image;
    colormap gray;
    title('Overlayed MIP');
end