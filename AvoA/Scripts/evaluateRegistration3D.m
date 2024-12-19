function score = evaluateRegistration3D(learningRate, stepSize)
    % Load 3D DICOM files
    fixedVolume = dicomread('fixedVolume.dcm');
    movingVolume = dicomread('movingVolume.dcm');

    % Pre-process the volumes (if necessary)
    fixedVolume = double(fixedVolume) / max(fixedVolume(:));
    movingVolume = double(movingVolume) / max(movingVolume(:));

    % Define optimizer and metric
    optimizer = registration.optimizer.GradientDescent;
    optimizer.LearningRate = learningRate;
    optimizer.MaximumStepLength = stepSize;

    metric = registration.metric.MeanSquares;

    try
        % Perform 3D image registration
        tform = imregtform(movingVolume, fixedVolume, 'rigid', optimizer, metric);
        registeredVolume = imwarp(movingVolume, tform, 'OutputView', imref3d(size(fixedVolume)));

        % Compute a performance metric (e.g., similarity score)
        score = -computeRegistrationQuality3D(registeredVolume, fixedVolume); % Minimize the negative quality
    catch
        score = Inf; % Penalize failed registrations
    end
end