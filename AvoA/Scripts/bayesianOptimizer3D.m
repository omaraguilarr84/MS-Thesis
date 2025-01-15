function [results] = bayesianOptimizer3D(fixedImage, movingImage, maxObjectiveEvaluations, useParallel)
    if useParallel == true
        c = parcluster('local');
        n_workers = c.NumWorkers;
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
    
    optimVars = [
        optimizableVariable('GradientMagnitudeTolerance', [1e-10, 1e-3], 'Transform', 'log'), ...
        optimizableVariable('MinimumStepLength', [1e-10, 1e-3], 'Transform', 'log'), ...
        optimizableVariable('MaximumStepLength', [1e-6, 1e-1], 'Transform', 'log'), ...
        optimizableVariable('MaximumIterations', [50, 1500], 'Type', 'integer'), ...
        optimizableVariable('RelaxationFactor', [0.3, 0.8]), ...
        optimizableVariable('PyramidLevel', [1, 5], 'Type', 'integer'), ...
        optimizableVariable('TransformType', {'similarity', 'affine'}, 'Type', 'categorical')
    ];
    
    results = bayesopt(@(params)objFcn(params, movingImage, fixedImage), ...
        optimVars, ...
        'Verbose', 1, ...
        'AcquisitionFunctionName', 'expected-improvement-plus', ...
        'MaxObjectiveEvaluations', maxObjectiveEvaluations, ...
        'UseParallel', useParallel);
end

function score = objFcn(params, movingImage, fixedImage)
    try
        tformType = char(params.TransformType);
        
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
            'OutputView', imref3d(size(fixedImage)));

        overlap = computeDice3D(fixedImage, registeredImage);
        score = -overlap;
    catch
        score = Inf;
    end
end