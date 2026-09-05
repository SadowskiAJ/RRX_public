close all

% JCP short note Figure 3 generator
%
% The dendrogram contains all 33 GNA2 submissions so that exact repeats and
% platform metadata remain visible. S3_ClusterAnalysis.m supplies the tree
% and cluster membership; this script only draws them.
requiredVariables = {'RRX_data', 'GNA2_Clusters'};
families = GNA2_Clusters; txt = 'GNA2';

for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, ...
        'Run S1_Build.m, S2_Frechet.m and S3_ClusterAnalysis.m before Fig3.m (missing %s).', ...
        requiredVariables{i});
end

% Figure controls
fontName = 'Times New Roman';
axisFontSize = 24;
leafFontSize = 15;
cellFontSize = 15;
titleFontSize = 30;
lineWidth = 1.25;
exportFilename = 'JCP_Fig3.png';
exportResolution = 600;
clusterLabelFontSize = 22;
cutLineWidth = 2.5;

% Use the precomputed clustering, also used by Figure 1.
clusterCut = families.cut;
clusterColours = families.colours;
linkageTree = families.tree;
clusterLabels = families.labels;
clusterSizes = families.sizes;
leafOrder = families.leafOrder;
highlightedClusters = families.highlighted;

% Dendrograms cannot display zero on a logarithmic axis. Exact-zero merges
% are therefore drawn at a separate baseline one decade below the smallest
% positive merge; their displayed tick remains labelled exactly zero.
positiveMerges = linkageTree(linkageTree(:,3) > 0, 3);
assert(~isempty(positiveMerges), 'At least one positive linkage is required.');
zeroExponent = floor(log10(min(positiveMerges))) - 1;
zeroHeight = 10^zeroExponent;
displayTree = linkageTree;
displayTree(displayTree(:,3) == 0, 3) = zeroHeight;

% Compact, directly labelled platform metadata. CPU colour distinguishes
% vendor; Abaqus colour is ordered by release year.
nSubmissions = numel(RRX_data);
cpuColours = zeros(nSubmissions, 3);
cpuCellLabels = strings(nSubmissions, 1);
abaqusColours = zeros(nSubmissions, 3);
abaqusCellLabels = strings(nSubmissions, 1);
releaseYears = arrayfun(@(r) releaseYear(r.sAbaqus_version), RRX_data);
knownReleases = unique(releaseYears(isfinite(releaseYears)), 'sorted');
releasePalette = turbo(max(1, numel(knownReleases)));
for i = 1:nSubmissions
    isa = upper(string(RRX_data(i).sCPU_ISA));
    if startsWith(isa, "AMD")
        cpuColours(i,:) = [0.8500 0.3250 0.0980];
        cpuCellLabels(i) = "A";
    elseif startsWith(isa, "INTEL")
        cpuColours(i,:) = [0 0.4470 0.7410];
        cpuCellLabels(i) = "I";
    else
        cpuColours(i,:) = [0.72 0.72 0.72];
        cpuCellLabels(i) = "?";
    end

    [knownRelease, releaseIndex] = ismember(releaseYears(i), knownReleases);
    if knownRelease
        abaqusColours(i,:) = releasePalette(releaseIndex,:);
        abaqusCellLabels(i) = string(sprintf('%02d', mod(releaseYears(i), 100)));
    else
        abaqusColours(i,:) = [0.72 0.72 0.72];
        abaqusCellLabels(i) = "?";
    end
end

fig = figure('units', 'normalized', 'outerposition', [0 0 1 1], 'Color', 'w');
set(fig, 'PaperPositionMode', 'auto');
t = tiledlayout(fig, 6, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
theme(fig, 'light');

% Dendrogram
axTree = nexttile(t, 1, [5 1]);
hold(axTree, 'on');
for k = 1:numel(highlightedClusters)
    positions = find(clusterLabels(leafOrder) == highlightedClusters(k));
    left = min(positions) - 0.45;
    right = max(positions) + 0.45;
    colour = clusterColours(1 + mod(k-1, size(clusterColours,1)),:);
    patch(axTree, [left right right left], ...
        [zeroHeight/2 zeroHeight/2 clusterCut clusterCut], ...
        0.90 + 0.10 .* colour, 'EdgeColor', 'red', ...
        'HandleVisibility', 'off', 'HitTest', 'off');
end
drawDendrogram(axTree, displayTree, leafOrder, zeroHeight/2, [0.16 0.16 0.16], lineWidth);
set(axTree, ...
    'YScale', 'log', 'TickDir', 'out', ...
    'XTick', 1:numel(RRX_data), 'XTickLabel', [], ...
    'FontName', fontName, 'FontSize', axisFontSize, ...
    'LineWidth', 1.0, 'Layer', 'top');
xlim(axTree, [0.5, numel(RRX_data) + 0.5]);

maximumExponent = ceil(log10(max([linkageTree(:,3); clusterCut])));
decadeStep = max(1, ceil((maximumExponent - zeroExponent)/5));
decades = (zeroExponent + 1):decadeStep:maximumExponent;
if isempty(decades) || decades(end) ~= maximumExponent
    decades(end + 1) = maximumExponent;
end
yticks(axTree, [zeroHeight, 10.^decades]);
yticklabels(axTree, [{'0'}, ...
    arrayfun(@(p) sprintf('10^{%d}', p), decades, ...
    'UniformOutput', false)]);
axTree.TickLabelInterpreter = 'tex';
ylim(axTree, [zeroHeight/2, 10^(maximumExponent + 0.18)]);

title(axTree, [txt,' response clustering vs CPU vendor and Abaqus release'], ...
    'FontName', fontName, 'FontSize', titleFontSize, ...
    'FontWeight', 'bold');
ylabel(axTree, 'Complete-linkage discrete Fréchet distance', ...
    'FontName', fontName, 'FontSize', axisFontSize);
addUntickedTopRightBorder(axTree);

% The cut changes only the displayed grouping: neither the distances nor
% the linkage tree are thresholded or recomputed from platform metadata.
yline(axTree, clusterCut, '--', 'Color', [0.2 0.2 0.2], ...
    'LineWidth', cutLineWidth, 'HandleVisibility', 'off');
exponent = floor(log10(clusterCut));
mantissa = clusterCut / 10^exponent;
if abs(mantissa - 1) < 1e-12
    cutValueLabel = sprintf('10^{%d}', exponent);
else
    cutValueLabel = sprintf('%g \\times 10^{%d}', mantissa, exponent);
end
text(axTree, numel(RRX_data) + 0.25, clusterCut * 2, ...
    {sprintf('Cut: $d = %s$', cutValueLabel), sprintf('%d clusters', numel(clusterSizes))}, ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'Interpreter', 'latex', 'FontName', fontName, 'FontSize', clusterLabelFontSize, ...
    'FontWeight', 'bold', 'BackgroundColor', 'white', 'Margin', 2);
for k = 1:numel(highlightedClusters)
    positions = find(clusterLabels(leafOrder) == highlightedClusters(k));
    colour = clusterColours(1 + mod(k-1, size(clusterColours,1)),:);
    text(axTree, mean([min(positions), max(positions)]), clusterCut / 3, ...
        sprintf('$C_{%d}\\;(n = %d)$', k, clusterSizes(highlightedClusters(k))), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'Interpreter', 'latex', 'FontName', fontName, 'FontSize', clusterLabelFontSize, ...
        'FontWeight', 'bold', 'Color', colour);
end

% Metadata bands, reordered to match the dendrogram leaves.
axMetadata = nexttile(t, 6);
metadataRGB = zeros(2, numel(RRX_data), 3);
for i = 1:numel(RRX_data)
    submission = leafOrder(i);
    metadataRGB(1,i,:) = cpuColours(submission,:);
    metadataRGB(2,i,:) = abaqusColours(submission,:);
end
image(axMetadata, metadataRGB);
hold(axMetadata, 'on');
for i = 1:numel(RRX_data)
    submission = leafOrder(i);
    text(axMetadata, i, 1, cpuCellLabels(submission), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontName', fontName, 'FontSize', cellFontSize, 'FontWeight', 'bold', ...
        'Color', contrastTextColour(cpuColours(submission,:)));
    text(axMetadata, i, 2, abaqusCellLabels(submission), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', ...
        'FontName', fontName, 'FontSize', cellFontSize, 'FontWeight', 'bold', ...
        'Color', contrastTextColour(abaqusColours(submission,:)));
end
set(axMetadata, ...
    'YDir', 'reverse', 'TickDir', 'out', ...
    'XTick', 1:numel(RRX_data), ...
    'XTickLabel', arrayfun(@(i) ...
        sprintf('$\\mathcal{S}_{%02d}$', i), leafOrder, ...
        'UniformOutput', false), ...
    'XTickLabelRotation', 90, ...
    'YTick', [1 2], 'YTickLabel', {'CPU vendor', 'Abaqus release'}, ...
    'TickLabelInterpreter', 'latex', ...
    'FontName', fontName, 'FontSize', leafFontSize, ...
    'LineWidth', 1.0, 'Layer', 'top');
xlim(axMetadata, [0.5, numel(RRX_data) + 0.5]);
ylim(axMetadata, [0.5 2.5]);
xlabel(axMetadata, 'Submission', ...
    'FontName', fontName, 'FontSize', axisFontSize);
addUntickedTopRightBorder(axMetadata);

% Publication-quality PNG export.
print(fig, exportFilename, '-dpng', sprintf('-r%d', exportResolution));


function year = releaseYear(version)
% Extract a four-digit Abaqus release year from its metadata string.
    token = regexp(char(string(version)), '(?<!\d)20\d{2}(?!\d)', ...
        'match', 'once');
    if isempty(token)
        year = NaN;
    else
        year = str2double(token);
    end
end


function colour = contrastTextColour(background)
% Select black or white text for legibility within a coloured cell.
    luminance = [0.299 0.587 0.114] * background(:);
    if luminance > 0.58
        colour = [0 0 0];
    else
        colour = [1 1 1];
    end
end


function drawDendrogram(ax, tree, leafOrder, baseline, colour, width)
% Draw a linkage tree directly, retaining a prescribed valid leaf order.
    n = size(tree, 1) + 1;
    nodeX = zeros(2*n - 1, 1);
    nodeY = baseline .* ones(2*n - 1, 1);
    for position = 1:n
        nodeX(leafOrder(position)) = position;
    end

    hold(ax, 'on');
    for merge = 1:n-1
        children = tree(merge, 1:2);
        child1 = children(1);
        child2 = children(2);
        parent = n + merge;
        height = tree(merge, 3);

        x1 = nodeX(child1);
        x2 = nodeX(child2);
        y1 = nodeY(child1);
        y2 = nodeY(child2);
        line(ax, [x1 x1 x2 x2], [y1 height height y2], ...
            'Color', colour, 'LineWidth', width);

        nodeX(parent) = (x1 + x2)/2;
        nodeY(parent) = height;
    end
end


function addUntickedTopRightBorder(ax)
% Retain a full frame without mirrored ticks on the top and right.
    box(ax, 'off');
    xl = xlim(ax);
    yl = ylim(ax);
    line(ax, xl, [yl(2), yl(2)], ...
        'Color', ax.XColor, 'LineWidth', ax.LineWidth, ...
        'HandleVisibility', 'off', 'HitTest', 'off', 'Clipping', 'off');
    line(ax, [xl(2), xl(2)], yl, ...
        'Color', ax.YColor, 'LineWidth', ax.LineWidth, ...
        'HandleVisibility', 'off', 'HitTest', 'off', 'Clipping', 'off');
end
