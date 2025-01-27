function [results] = bayesianOptimizer2D(fixedImage, movingImage, maxObjectiveEvaluations, useParallel, stepType)
    if strcmp(stepType, 'shell')
        expRatio = 0.9;
        thresh = -0.98;

        optimVars = [
            optimizableVariable('GradientMagnitudeTolerance', [1e-10, 1e-3], 'Transform', 'log'), ...
            optimizableVariable('MinimumStepLength', [1e-10, 1e-3], 'Transform', 'log'), ...
            optimizableVariable('MaximumStepLength', [1e-6, 1e-1], 'Transform', 'log'), ...
            optimizableVariable('MaximumIterations', [50, 1500], 'Type', 'integer'), ...
            optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
            optimizableVariable('PyramidLevel', [1, 5], 'Type', 'integer'), ...
            optimizableVariable('TransformType', {'similarity', 'affine'}, 'Type', 'categorical')
        ];
    elseif strcmp(stepType, 'mid')
        expRatio = 0.5;
        thresh = -0.9;

        optimVars = [
            optimizableVariable('GradientMagnitudeTolerance', [1e-10, 1e-3], 'Transform', 'log'), ...
            optimizableVariable('MinimumStepLength', [1e-10, 1e-3], 'Transform', 'log'), ...
            optimizableVariable('MaximumStepLength', [1e-6, 1e-1], 'Transform', 'log'), ...
            optimizableVariable('MaximumIterations', [50, 1500], 'Type', 'integer'), ...
            optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
            optimizableVariable('PyramidLevel', [1, 5], 'Type', 'integer'), ...
        ];
    end


    if useParallel == true
        c = parcluster('local');
        n_workers = c.NumWorkers - 2;
        pool = gcp('nocreate');
        if isempty(pool)
            parpool('local', n_workers);
        else
            if pool.NumWorkers ~= n_workers
                delete(pool);
                parpool('local', n_workers);
            end
        end
    end
    
    % Create a custom output function to monitor progress
    consecutiveThreshold = 10;
    thresholdValue = thresh;
    bestEval = Inf;
    consecutiveCount = 0;
    
    function stop = earlyStopFcn(results, state)
        stop = false;
        if state == "iteration"
            % Update best evaluation and count consecutive iterations
            if results.MinObjective < thresholdValue
                consecutiveCount = consecutiveCount + 1;
            else
                consecutiveCount = 0;
            end
            
            % Check if the threshold has been met for the desired iterations
            if consecutiveCount >= consecutiveThreshold
                stop = true;
                disp("Early stopping triggered: Best observed evaluation has been below the threshold for 10 iterations.");
            end
        end
    end

    % Run Bayesian optimization
    results = bayesopt(@(params)objFcn(params, movingImage, fixedImage, stepType), ...
        optimVars, ...
        'Verbose', 1, ...
        'AcquisitionFunctionName', 'expected-improvement-plus', ...
        'ExplorationRatio', expRatio, ...
        'MaxObjectiveEvaluations', maxObjectiveEvaluations, ...
        'UseParallel', useParallel, ...
        'OutputFcn', @earlyStopFcn);
end

function score = objFcn(params, movingImage, fixedImage, stepType)
    try
        if strcmp(stepType, 'shell')
            tformType = char(params.TransformType);
        elseif strcmp(stepType, 'mid')
            tformType = 'translation';
        end
        
        [optimizer, metric] = imregconfig('monomodal');
        optimizer.GradientMagnitudeTolerance = params.GradientMagnitudeTolerance;
        optimizer.MinimumStepLength = params.MinimumStepLength;
        optimizer.MaximumStepLength = params.MaximumStepLength;
        optimizer.MaximumIterations = params.MaximumIterations;
        optimizer.RelaxationFactor = params.RelaxationFactor;

        tform = imregtform(movingImage, fixedImage, ...
            tformType, optimizer, metric, ...
            'PyramidLevels', params.PyramidLevel);
        registeredImage = imwarp(movingImage, tform, ...
            'OutputView', imref2d(size(fixedImage)));

        overlap = computeDice3D(fixedImage, registeredImage);
        score = -overlap;
    catch
        score = Inf;
    end
end