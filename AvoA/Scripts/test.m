clc;

% Load your fixed and moving images
fixedImage = fixedShell;  % Replace with your fixed image path
movingImage = movingShell; % Replace with your moving image path
% Convert images to grayscale if they are RGB
if size(fixedImage, 3) == 3
    fixedImage = rgb2gray(fixedImage);
end
if size(movingImage, 3) == 3
    movingImage = rgb2gray(movingImage);
end

% Binarize the images (optional, depending on your data)
fixedBinary = imbinarize(fixedImage);
movingBinary = imbinarize(movingImage);

% Define the optimization function to maximize Dice coefficient
objectiveFunction = @(params) -computeDice(fixedBinary, ...
    imwarp(movingBinary, affine2d(makeTransform(params)), ...
    'OutputView', imref2d(size(fixedBinary))));

% Initial parameters: [translation_x, translation_y, rotation_angle]
initialParams = [0, 0, 0]; % Initial guess: no translation or rotation

% Perform optimization (e.g., using fminsearch)
optimizedParams = fminsearch(objectiveFunction, initialParams);

% Apply the optimized transformation
optimizedTransform = affine2d(makeTransform(optimizedParams));
registeredImage = imwarp(movingImage, optimizedTransform, ...
    'OutputView', imref2d(size(fixedBinary)));

% Display results
figure;
subplot(1, 3, 1); imshow(fixedImage); title('Fixed Image');
subplot(1, 3, 2); imshow(movingImage); title('Moving Image');
subplot(1, 3, 3); imshow(registeredImage); title('Registered Image');

% Function to compute the Dice coefficient
function diceScore = computeDice(fixed, moving)
    intersection = sum(fixed(:) & moving(:));
    totalPixels = sum(fixed(:)) + sum(moving(:));
    if totalPixels == 0
        diceScore = 1; % Perfect match for empty images
    else
        diceScore = (2 * intersection) / totalPixels;
    end
end

% Function to create an affine transformation matrix
function tformMatrix = makeTransform(params)
    tx = params(1); % Translation in x
    ty = params(2); % Translation in y
    theta = deg2rad(params(3)); % Rotation angle in radians

    tformMatrix = [
        cos(theta), -sin(theta), 0;
        sin(theta),  cos(theta), 0;
        tx,          ty,          1
    ];
end