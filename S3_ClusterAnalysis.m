close all

% S1_Build.m supplies the submissions and fingerprint maps;
% S2_Frechet.m supplies the unique-history distance matrices.
requiredVariables = {'RRX_data', 'unique_MNA', 'unique_GNA1', 'unique_GNA2', 'unique_GNA3', ...
                     'MNA_Frechet', 'GNA1_Frechet', 'GNA2_Frechet', 'GNA3_Frechet'};
for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, 'Run S1_Build.m and S2_Frechet.m before S3_ClusterAnalysis.m (missing %s).', requiredVariables{i});
end

% Clustering controls, shared by all analyses and their figures.
clusterCutMNA = 1e-10; clusterCutGNA = 1e-6; 
largestClustersToHighlight = 3;
clusterColours = [0.00 0.35 0.85; ... % C1: blue
                  0.10 0.55 0.20; ... % C2: green
                  0.95 0.45 0.05];    % C3: orange

MNA_Clusters  = clusterResponses(unique_MNA,  RRX_data, MNA_Frechet,  clusterCutMNA, largestClustersToHighlight, clusterColours);
GNA1_Clusters = clusterResponses(unique_GNA1, RRX_data, GNA1_Frechet, clusterCutGNA, largestClustersToHighlight, clusterColours);
GNA2_Clusters = clusterResponses(unique_GNA2, RRX_data, GNA2_Frechet, clusterCutGNA, largestClustersToHighlight, clusterColours);
GNA3_Clusters = clusterResponses(unique_GNA3, RRX_data, GNA3_Frechet, clusterCutGNA, largestClustersToHighlight, clusterColours);

disp(['MNA:  ', num2str(numel(MNA_Clusters.sizes)),  ' clusters.']);
disp(['GNA1: ', num2str(numel(GNA1_Clusters.sizes)), ' clusters.']);
disp(['GNA2: ', num2str(numel(GNA2_Clusters.sizes)), ' clusters.']);
disp(['GNA3: ', num2str(numel(GNA3_Clusters.sizes)), ' clusters.']);


function families = clusterResponses(resultMap, RRX_data, distances, cut, largestClustersToHighlight, colours)
% Build a complete-linkage tree for all submissions, retaining multiplicities.
% Outputs contain the tree, cut membership, sizes and ordered leaves, plus
% representative submission indices, labels and colours for highlighting.
% C1, C2, C3 are local to each analysis, not matched across analyses.
    families.cut = cut;
    families.colours = colours;

    % Match the first-submission ordering used by S2_Frechet.m.
    groups = values(resultMap);
    firstSubmission = cellfun(@(members) double(members(1)), groups);
    [~, order] = sort(firstSubmission);
    groups = groups(order);
    n = numel(RRX_data);
    assert(isequal(size(distances), [numel(groups), numel(groups)]), ...
        'The Frechet matrix does not match the fingerprint groups.');
    membership = zeros(n, 1);
    for response = 1:numel(groups)
        membership(double(groups{response})) = response;
    end
    assert(all(membership > 0), 'Every submission must belong to a response group.');

    % Expand by indexing only: no additional Frechet distances are computed.
    families.distances = distances(membership, membership);
    condensedDistances = squareform(families.distances);
    families.tree = linkage(condensedDistances, 'complete');
    families.labels = cluster(families.tree, 'Cutoff', families.cut, 'Criterion', 'distance');
    families.sizes = accumarray(families.labels, 1);
    families.leafOrder = optimalleaforder(families.tree, condensedDistances);

    % Rank by number of submissions, breaking ties by position in the tree.
    % Assign C1, C2, C3 from left to right within each analysis.
    firstLeaf = accumarray(families.labels(families.leafOrder(:)), (1:n).', [], @min);
    [~, ranked] = sortrows([-families.sizes, firstLeaf], [1 2]);
    ranked = ranked(families.sizes(ranked) > 1);
    selected = ranked(1:min(largestClustersToHighlight, numel(ranked)));
    [~, leftToRight] = sort(firstLeaf(selected));
    families.highlighted = selected(leftToRight);
    families.representatives = zeros(numel(selected), 1);
    families.names = cell(numel(selected), 1);
    for k = 1:numel(selected)
        % Use the first submitted history in each highlighted family.
        families.representatives(k) = find(families.labels == families.highlighted(k), 1);
        families.names{k} = sprintf('$C_{%d}$', k);
    end
end
