close all

% JCP short note Figure 1 generator

% S1_Build.m supplies the full submission array and the per-analysis
% fingerprint maps; S3_ClusterAnalysis.m supplies the GNA2 clusters.
% Do not clear the workspace here, as that would remove these variables.
requiredVariables = {'RRX_data', 'unique_MNA', 'unique_GNA1', 'unique_GNA2', 'unique_GNA3', 'GNA2_Clusters'};
for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, 'Run S1_Build.m, S2_Frechet.m and S3_ClusterAnalysis.m before Fig1.m (missing %s).', requiredVariables{i});
end

referenceFile = 'ReferenceResults.xlsx';
MNAref_path = abs(readmatrix(referenceFile, 'Range', 'D13:E88'));
MNAref_shape = readmatrix(referenceFile, 'Range', 'J13:K113');
GNAref_path = abs(readmatrix(referenceFile, 'Range', 'M13:N113'));
GNAref_shape = readmatrix(referenceFile, 'Range', 'S13:T113');

% Each cell contains [LPF, Uend] from the first submission in one exact fingerprint group.
MNAcurves  = uniqueLPFUendCurves(RRX_data, unique_MNA,  'cMNA_Block');
GNA1curves = uniqueLPFUendCurves(RRX_data, unique_GNA1, 'cGNA1_Block');
GNA2curves = uniqueLPFUendCurves(RRX_data, unique_GNA2, 'cGNA2_Block');
GNA3curves = uniqueLPFUendCurves(RRX_data, unique_GNA3, 'cGNA3_Block');
GNAcurves  = [GNA1curves, GNA2curves, GNA3curves];
families = GNA2_Clusters;

% Figure controls
fig = figure('units', 'normalized', 'outerposition', [0 0 1 1], 'Color', 'w');
t = tiledlayout(2, 6, "TileSpacing", "compact", "Padding", "loose"); theme(fig,'light');
dx = 0.1; dy = 0.025;
axisFontName = 'Times New Roman';
axisFontSize = 24;
zoomAxisFontSize = 16;
labelFontSize = 24;
titleFontSize = 24;
legendFontSize = 24;
zoomLabelFontSize = 18;
expectedResponseLineWidth = 3;
computedResponseLineWidth = 0.75;
computedResponseColor = [0.90 0 0];
familyLineWidth = 4;
familyLegendFontSize = 20;
exportFilename = 'JCP_Fig1.png';
exportResolution = 600;

% MNA control target
ax = nexttile(1, [2 1]);
MNAshapeAx = ax;
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
plot(MNAref_shape(:,2), MNAref_shape(:,1), 'k', 'LineWidth', 2);
plot([0 0], [0 1], 'k--', 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]); 
xlim([-dx 1+dx]);
ylim([-dy 1]);
set(ax, 'YDir', 'reverse');

% MNA control curves
ax = nexttile(2, [2 2]);
MNAcurveAx = ax;
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
MNAexpectedLine = plot(ax, MNAref_path(:,2), MNAref_path(:,1), 'k--', 'LineWidth', expectedResponseLineWidth);
for i = 1:numel(MNAcurves)
    h = plot(ax, abs(MNAcurves{i}(:,2)), MNAcurves{i}(:,1), '-', 'Color', computedResponseColor, 'LineWidth', computedResponseLineWidth);
    if i == 1; MNAcomputedLine = h; end
end
xlim([0 1.66]);
ylim([0 1+dy]);
legend(MNAcurveAx, [MNAexpectedLine, MNAcomputedLine], ...
    {'Expected', 'Computed'}, ...
    'Location', 'northwest', 'AutoUpdate', 'off', ...
    'FontName', axisFontName, 'FontSize', legendFontSize, 'Box', 'on');

% GNA control target
ax = nexttile(4, [2 1]);
GNAshapeAx = ax;
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
plot(GNAref_shape(:,2), GNAref_shape(:,1), 'k', 'LineWidth', 2);
plot([0 0], [0 1], 'k--', 'LineWidth', 1.5, 'Color', [0.5 0.5 0.5]);
xlim([-1 1+dx]);
ylim([-dy 1]);
set(ax, 'YDir', 'reverse');

% GNA control curves
ax = nexttile(5, [2 2]);
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
plot(ax, GNAref_path(:,2), GNAref_path(:,1), 'k--', 'LineWidth', expectedResponseLineWidth);
for i = 1:numel(GNAcurves)
    plot(ax, abs(GNAcurves{i}(:,2)), GNAcurves{i}(:,1), ...
        'Color', computedResponseColor, ...
        'LineWidth', computedResponseLineWidth);
end
xlim([0 1.52]);
ylim([0 1+dy]);

% Static zoom overlay on tile 5.
GNAax = ax;
zoomX = [0.4 1.0];
zoomY = [0.68 1.02];

% Mark the magnified region on the main plot.
rectangle(GNAax, ...
    'Position', [zoomX(1), zoomY(1), diff(zoomX), diff(zoomY)], ...
    'EdgeColor', [0.35 0.35 0.35], 'LineWidth', 1.5);

% Place a larger inset explicitly in the lower-right of the figure,
% within the area occupied by tile 5. Coordinates are normalized to fig.
insetPos = [0.78 0.14 0.21 0.50];

GNAzoomAx = axes(fig, 'Units', 'normalized', 'Position', insetPos, 'Color', 'w', 'Box', 'on', 'LineWidth', 1.25);
hold(GNAzoomAx, 'on'); grid(GNAzoomAx, 'on');

plot(GNAzoomAx, GNAref_path(:,2), GNAref_path(:,1), 'k--', 'LineWidth', expectedResponseLineWidth);
for i = 1:numel(GNAcurves)
    plot(GNAzoomAx, abs(GNAcurves{i}(:,2)), GNAcurves{i}(:,1), ...
        'Color', computedResponseColor, ...
        'LineWidth', computedResponseLineWidth);
end
familyLines = plotFamilyCurves(GNAzoomAx, RRX_data, families, familyLineWidth);
xlim(GNAzoomAx, zoomX);
ylim(GNAzoomAx, zoomY);
axis(GNAzoomAx, 'manual');
familyLegend = legend(GNAzoomAx, familyLines, families.names, ...
    'Location', 'southeast', 'AutoUpdate', 'off', 'Interpreter', 'latex', ...
    'FontSize', familyLegendFontSize, 'Box', 'on');
familyLegend.Title.String = 'GNA2';
text(GNAzoomAx, 0.03, 0.97, 'Zoom', ...
    'Units', 'normalized', ...
    'HorizontalAlignment', 'left', 'VerticalAlignment', 'top', ...
    'FontName', axisFontName, 'FontSize', zoomLabelFontSize, ...
    'FontWeight', 'bold', 'BackgroundColor', 'white', 'Margin', 1);

% Consistent tick-label typography and significant-figure formatting.
mainAxes = [MNAshapeAx, MNAcurveAx, GNAshapeAx, GNAax];
set(mainAxes, 'FontName', axisFontName, 'FontSize', axisFontSize, 'TickDir', 'out');
for k = 1:numel(mainAxes)
    xtickformat(mainAxes(k), '%#.1g');
    ytickformat(mainAxes(k), '%#.1g');
end

set(GNAzoomAx, 'FontName', axisFontName, 'FontSize', zoomAxisFontSize, 'TickDir', 'out');
xtickformat(GNAzoomAx, '%#.1g');
ytickformat(GNAzoomAx, '%#.2g');

% Tile titles and axis labels.
title(MNAshapeAx, 'MNA target', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(MNAshapeAx, '$w$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(MNAshapeAx, 'Normalised height', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(MNAcurveAx, 'MNA response', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(MNAcurveAx, '$|u|$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(MNAcurveAx, 'Load proportionality factor', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(GNAshapeAx, 'GNA target', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(GNAshapeAx, '$w$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(GNAshapeAx, 'Normalised height', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(GNAax, 'GNA response', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(GNAax, '$|u|$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(GNAax, 'Load proportionality factor', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

% Keep the top/right borders, but show ticks only on the bottom/left.
allAxes = [mainAxes, GNAzoomAx];
for k = 1:numel(allAxes)
    addUntickedTopRightBorder(allAxes(k));
end

% Lossless, publication-quality PNG export.
exportgraphics(fig, exportFilename, 'Resolution', exportResolution, 'BackgroundColor', 'white');


function handles = plotFamilyCurves(ax, RRX_data, families, width)
% Emphasise the three GNA2 families in the zoom inset.
    handles = gobjects(numel(families.representatives), 1);
    for k = 1:numel(handles)
        block = RRX_data(families.representatives(k)).cGNA2_Block;
        handles(k) = plot(ax, abs(block.vdU), block.vdLPF, '-', ...
            'Color', families.colours(k,:), 'LineWidth', width, ...
            'DisplayName', families.names{k});
    end
end


function curves = uniqueLPFUendCurves(RRX_data, resultMap, blockField)
% Return one representative [LPF, Uend] curve per map key.
    groups = values(resultMap);

    % Plot representatives deterministically in first-submission order.
    firstSubmission = cellfun(@(members) double(members(1)), groups);
    [~, order] = sort(firstSubmission);
    groups = groups(order);

    curves = cell(1, numel(groups));
    for i = 1:numel(groups)
        representative = double(groups{i}(1));
        block = RRX_data(representative).(blockField);
        valid = isfinite(block.vdLPF) & isfinite(block.vdU);
        curves{i} = [block.vdLPF(valid), block.vdU(valid)];
    end
end

function addUntickedTopRightBorder(ax)
% Retain a full frame without mirrored ticks.
    box(ax, 'off');
    xl = xlim(ax);
    yl = ylim(ax);

    if strcmpi(ax.XDir, 'reverse')
        xRight = xl(1);
    else
        xRight = xl(2);
    end

    if strcmpi(ax.YDir, 'reverse')
        yTop = yl(1);
    else
        yTop = yl(2);
    end

    line(ax, xl, [yTop yTop], ...
        'Color', ax.XColor, 'LineWidth', ax.LineWidth, ...
        'HandleVisibility', 'off', 'HitTest', 'off', 'Clipping', 'off');
    line(ax, [xRight xRight], yl, ...
        'Color', ax.YColor, 'LineWidth', ax.LineWidth, ...
        'HandleVisibility', 'off', 'HitTest', 'off', 'Clipping', 'off');
end
