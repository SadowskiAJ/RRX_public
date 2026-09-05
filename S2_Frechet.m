close all

% Sigma policy:
%   'pooled' - all 33 submitted histories, including multiplicities
%   'unique' - one representative history per fingerprint group
sigmaPolicy = 'unique';

MNA_Frechet = matrixFrechet(unique_MNA, RRX_data, 'MNA', sigmaPolicy);
GNA1_Frechet = matrixFrechet(unique_GNA1, RRX_data, 'GNA1', sigmaPolicy);
GNA2_Frechet = matrixFrechet(unique_GNA2, RRX_data, 'GNA2', sigmaPolicy);
GNA3_Frechet = matrixFrechet(unique_GNA3, RRX_data, 'GNA3', sigmaPolicy);

function Fmatrix = matrixFrechet(unique_what, RRX_data, what, sigmaPolicy)
    groups = values(unique_what);
    representatives = cellfun(@(members) double(members(1)), groups);
    representatives = sort(representatives);
    n = numel(representatives);
    Fmatrix = zeros(n,n);

    % Standard deviation
    sigmas = frechetSigmas(unique_what, RRX_data, what, sigmaPolicy);

    % Dictionary selector to fingerprint field path
    switch what
        case 'MNA',  fld = 'cMNA_Block';
        case 'GNA1', fld = 'cGNA1_Block';
        case 'GNA2', fld = 'cGNA2_Block';
        case 'GNA3', fld = 'cGNA3_Block';
        otherwise, error('Unknown ''what'' value.');
    end    

    for I = 1:n
        blockI = RRX_data(representatives(I)).(fld);
        for J = I+1:n
            blockJ = RRX_data(representatives(J)).(fld);
            curveI = [blockI.vdLPF, blockI.vdU, blockI.vdMaxRes];
            curveJ = [blockJ.vdLPF, blockJ.vdU, blockJ.vdMaxRes];

            distance = discreteFrechet(curveI, curveJ, sigmas);
            Fmatrix(I, J) = distance;
            Fmatrix(J, I) = distance;
        end
    end
end


function sigmas = frechetSigmas(unique_what, RRX_data, what, policy)
% Calculate coordinate scales under a selectable policy.
% 'pooled' uses all submissions, so duplicate histories contribute with their observed multiplicities. 
% 'unique' uses only the first submission in each exact fingerprint group.

    switch upper(what)
        case 'MNA',  fld = 'cMNA_Block';
        case 'GNA1', fld = 'cGNA1_Block';
        case 'GNA2', fld = 'cGNA2_Block';
        case 'GNA3', fld = 'cGNA3_Block';
        otherwise, error('Unknown ''what'' value.');
    end

    policy = lower(char(policy));
    switch policy
        case 'pooled'
            indices = 1:numel(RRX_data);

        case 'unique'
            groups = values(unique_what);
            indices = cellfun(@(members) double(members(1)), groups);

        otherwise
            error('Unknown sigma policy ''%s''. Use ''pooled'' or ''unique''.', policy);
    end

    samples = cell(numel(indices), 1);
    for i = 1:numel(indices)
        block = RRX_data(indices(i)).(fld);
        samples{i} = [block.vdLPF(:), block.vdU(:), block.vdMaxRes(:)];
    end
    samples = vertcat(samples{:});

    % NaNs are legitimate missing residual diagnostics. They are omitted
    % only from the residual standard-deviation calculation.
    sigmas = std(samples, 0, 1, 'omitnan');

    if any(~isfinite(sigmas)) || any(sigmas <= 0)
        error('Calculated sigmas must be finite and strictly positive.');
    end
end


function [distance, accumulatedCost, pointCost] = discreteFrechet(curveA, curveB, scales)
% Multivariate discrete Frechet distance.
%
% distance = discreteFrechet(curveA, curveB)
% distance = discreteFrechet(curveA, curveB, scales)
%
% curveA and curveB:
%   M-by-D and N-by-D arrays. Rows are ordered curve points and
%   columns are coordinates.
%
% scales:
%   Scalar or 1-by-D vector of positive coordinate scale factors.
%   The default is ones(1,D), giving ordinary Euclidean distance.
%
% Outputs:
%   distance         - scalar discrete Frechet distance
%   accumulatedCost  - M-by-N dynamic-programming matrix
%   pointCost        - M-by-N pointwise-distance matrix

    validateattributes(curveA, {'numeric'}, {'real', '2d', 'nonempty'}, mfilename, 'curveA');
    validateattributes(curveB, {'numeric'}, {'real', '2d', 'nonempty'}, mfilename, 'curveB');

    curveA = double(curveA);
    curveB = double(curveB);

    [m, dimensionsA] = size(curveA);
    [n, dimensionsB] = size(curveB);

    if dimensionsA ~= dimensionsB
        error('The two curves must have the same number of coordinates.');
    end

    % NaN coordinates are allowed and are omitted from the corresponding
    % pointwise cost. Infinite coordinates remain invalid.
    if any(isinf(curveA), 'all') || any(isinf(curveB), 'all')
        error('Curve coordinates must not contain Inf.');
    end

    if nargin < 3 || isempty(scales)
        scales = ones(1, dimensionsA);
    elseif isscalar(scales)
        scales = repmat(scales, 1, dimensionsA);
    else
        scales = double(scales(:).');
    end

    if numel(scales) ~= dimensionsA
        error('scales must be scalar or contain one value per coordinate.');
    end

    if any(~isfinite(scales)) || any(scales <= 0)
        error('All scale factors must be finite and strictly positive.');
    end

    % Apply the coordinate scaling once.
    scaledA = curveA ./ scales;
    scaledB = curveB ./ scales;

    % Pointwise Euclidean costs.
    pointCost = zeros(m, n);

    for i = 1:m
        differences = scaledB - scaledA(i,:);
        available = ~isnan(differences);

        if any(~any(available, 2))
            error('A point pair has no commonly available coordinates.');
        end

        differences(~available) = 0;
        pointCost(i,:) = sqrt(sum(differences.^2, 2)).';
    end

    % Dynamic-programming recurrence.
    accumulatedCost = inf(m, n);

    for i = 1:m
        for j = 1:n
            cost = pointCost(i,j);
            if i == 1 && j == 1; accumulatedCost(i,j) = cost;
            elseif i == 1; accumulatedCost(i,j) = max(cost, accumulatedCost(i,j-1));
            elseif j == 1; accumulatedCost(i,j) = max(cost, accumulatedCost(i-1,j));
            else
                previous = min(accumulatedCost(i-1,j), ...
                    min(accumulatedCost(i-1,j-1), accumulatedCost(i,j-1)));
                accumulatedCost(i,j) = max(cost, previous);
            end
        end
    end

    distance = accumulatedCost(m,n);
end
