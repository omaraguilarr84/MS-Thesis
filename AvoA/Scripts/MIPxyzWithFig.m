function MIP = MIPxyzWithFig(IM, showFigure)
    if nargin < 2
        showFigure = false;
    end
    
    MIP.z = max(IM,[],3);
    MIP.x = squeeze(max(IM,[],2));
    MIP.y = squeeze(max(IM,[],1));
    
    tmp = zeros(size(IM,3),class(IM));
    
    MIP.tile = [
        MIP.z, fliplr(MIP.x)
        flipud(transpose(MIP.y)), tmp
        ];
    
    if showFigure
        figure(1);imagesc(MIP.tile);axis image; colormap gray
    end
end