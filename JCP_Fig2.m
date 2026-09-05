close all

% JCP short note Figure 2 generator
%
% S2_Frechet.m supplies pairwise distances between the deduplicated MNA
% and GNA2 histories. Positive distances share one logarithmic colour
% scale; exact zeros occupy a separate neutral-colour band.
requiredVariables = {'MNA_Frechet', 'GNA2_Frechet', ...
                     'unique_MNA', 'unique_GNA2'};
for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, 'Run S1_Build.m and S2_Frechet.m before Fig2.m (missing %s).',requiredVariables{i});
end

% Figure controls
axisFontName = 'Times New Roman';
tickFontSize = 24;
labelFontSize = 24;
titleFontSize = 30;
colourbarFontSize = 24;
frameLineWidth = 1.0;
exportFilename = 'JCP_Fig2.png';
exportResolution = 600;
numberOfColours = 256;
zeroBandColours = 26;
zeroColour = [0.86 0.86 0.86];

% Establish one common logarithmic scale so that colours are comparable
% between the MNA and GNA2 panels. No positive value is thresholded: the
% least-significant-bit differences are deliberately retained.
positiveDistances = [MNA_Frechet(MNA_Frechet > 0); ...
                     GNA2_Frechet(GNA2_Frechet > 0)];
assert(~isempty(positiveDistances), ...
    'At least one positive Fréchet distance is required.');

logMinimum = floor(log10(min(positiveDistances)));
logMaximum = ceil(log10(max(positiveDistances)));
if logMaximum == logMinimum
    logMaximum = logMinimum + 1;
end

% Reserve a visible portion of the colourbar for the categorical zero.
% All remaining colours describe log10(distance) continuously.
positiveBandStart = zeroBandColours/(numberOfColours - 1);
colourMap = [repmat(zeroColour, zeroBandColours, 1); ...
             turbo(numberOfColours - zeroBandColours)];

fig = figure('units', 'normalized', 'outerposition', [0 0 1 1], 'Color', 'w');
t = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
theme(fig, 'light');
colormap(fig, colourMap);

axMNA = nexttile(t, 1);
MNAcounts = orderedGroupCounts(unique_MNA);
plotDistanceMatrix(axMNA, MNA_Frechet, MNAcounts, 'MNA', ...
    axisFontName, tickFontSize, labelFontSize, titleFontSize, ...
    colourbarFontSize, frameLineWidth, logMinimum, logMaximum, ...
    positiveBandStart);

axGNA2 = nexttile(t, 2);
GNA2counts = orderedGroupCounts(unique_GNA2);
plotDistanceMatrix(axGNA2, GNA2_Frechet, GNA2counts, 'GNA2', ...
    axisFontName, tickFontSize, labelFontSize, titleFontSize, ...
    colourbarFontSize, frameLineWidth, logMinimum, logMaximum, ...
    positiveBandStart);

% Lossless, publication-quality raster export.
exportgraphics(t, exportFilename, 'Resolution', exportResolution, 'BackgroundColor', 'white');


function plotDistanceMatrix(ax, distances, groupCounts, panelTitle, fontName, ...
        tickSize, labelSize, titleSize, colourbarSize, frameWidth, ...
        logMinimum, logMaximum, positiveBandStart)
%PLOTDISTANCEMATRIX Draw one square discrete-Frechet distance matrix.

    validateattributes(distances, {'numeric'}, ...
        {'real', '2d', 'finite', 'nonnegative'});
    assert(size(distances, 1) == size(distances, 2), ...
        'A Frechet distance matrix must be square.');
    assert(max(abs(distances - distances.'), [], 'all') < 1e-10, ...
        'A Frechet distance matrix must be symmetric.');

    n = size(distances, 1);
    assert(numel(groupCounts) == n, ...
        'The deduplication group count must match the matrix size.');
    responseLabels = arrayfun(@(i) ...
        sprintf('$\\mathcal{R}_{%02d}$', i), 1:n, ...
        'UniformOutput', false);
    responseCountLabels = arrayfun(@(i) ...
        sprintf('$\\mathcal{R}_{%02d}\\;(n = %d)$', ...
        i, groupCounts(i)), 1:n, 'UniformOutput', false);

    % Encode exact zero categorically at 0. Positive distances occupy the
    % remainder of [0,1] according to their base-10 logarithms.
    imageValues = zeros(size(distances));
    isPositive = distances > 0;
    imageValues(isPositive) = positiveBandStart + ...
        (1 - positiveBandStart) .* ...
        (log10(distances(isPositive)) - logMinimum) ./ ...
        (logMaximum - logMinimum);

    imagesc(ax, imageValues, [0 1]);
    xlim(ax, [0.5, n + 0.5]);
    ylim(ax, [0.5, n + 0.5]);
    set(ax, ...
        'DataAspectRatio', [1 1 1], ...
        'PlotBoxAspectRatio', [1 1 1], ...
        'YDir', 'normal', ...
        'XTick', 1:n, 'YTick', 1:n, ...
        'XTickLabel', responseCountLabels, ...
        'YTickLabel', responseLabels, ...
        'TickLabelInterpreter', 'latex', ...
        'XTickLabelRotation', 45, ...
        'TickDir', 'out', 'TickLength', [0.009 0.009], ...
        'FontName', fontName, 'FontSize', tickSize, ...
        'LineWidth', frameWidth, 'Layer', 'top');

    title(ax, panelTitle, ...
        'FontName', fontName, 'FontSize', titleSize, ...
        'FontWeight', 'bold');
    xlabel(ax, 'Unique response', ...
        'FontName', fontName, 'FontSize', labelSize);
    ylabel(ax, 'Unique response', ...
        'FontName', fontName, 'FontSize', labelSize);

    % Show the original distance decades on the transformed colourbar.
    decadeStep = max(1, ceil((logMaximum - logMinimum)/5));
    decades = logMinimum:decadeStep:logMaximum;
    if decades(end) ~= logMaximum
        decades(end + 1) = logMaximum;
    end
    decadePositions = positiveBandStart + ...
        (1 - positiveBandStart) .* ...
        (decades - logMinimum) ./ (logMaximum - logMinimum);
    tickPositions = [0, decadePositions];
    tickLabels = [{'0'}, ...
        arrayfun(@(p) sprintf('10^{%d}', p), decades, ...
        'UniformOutput', false)];

    cb = colorbar(ax, 'eastoutside');
    set(cb, ...
        'Ticks', tickPositions, 'TickLabels', tickLabels, ...
        'TickLabelInterpreter', 'tex', 'TickDirection', 'out', ...
        'FontName', fontName, 'FontSize', colourbarSize, ...
        'LineWidth', frameWidth);
    cb.Label.String = 'Discrete Fréchet distance';
    cb.Label.FontName = fontName;
    cb.Label.FontSize = labelSize;

    addUntickedTopRightBorder(ax);
end


function counts = orderedGroupCounts(resultMap)
% Return group multiplicities in the same order used by matrixFrechet.
    groups = values(resultMap);
    firstSubmission = cellfun(@(members) double(members(1)), groups);
    [~, order] = sort(firstSubmission);
    groups = groups(order);
    counts = cellfun(@numel, groups);
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
