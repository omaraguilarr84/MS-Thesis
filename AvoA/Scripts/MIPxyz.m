%% MIP in 3 views for images.
%% xy orientiations are kind of arbitrary; 
%% orientation in tile is also somewhat arbitrary, this is meant for quick display only, views might be flipped.
%% Amir Pourmorteza 2024 Aug 19

function MIP = MIPxyz(IM)

MIP.z = max(IM,[],3);
MIP.x = squeeze(max(IM,[],2));
MIP.y = squeeze(max(IM,[],1));

tmp = zeros(size(IM,3),class(IM));
%%
MIP.tile = [
    MIP.z, fliplr(MIP.x)
    flipud(transpose(MIP.y)), tmp
    ];
figure(1);imagesc(MIP.tile);axis image; colormap gray


end