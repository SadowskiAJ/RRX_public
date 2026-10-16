close all

% RRX Figure 1: benchmark targets and overall response histories

% S1_Build.m supplies the full submission array and the per-analysis
% fingerprint maps. RRX_Fig2.m shows the enlarged GNA response families.
% Do not clear the workspace here, as that would remove these variables.
requiredVariables = {'RRX_data', 'unique_MNA', 'unique_GNA1', 'unique_GNA2', 'unique_GNA3'};
for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, 'Run S1_Build.m before RRX_Fig1.m (missing %s).', requiredVariables{i});
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

% Figure controls
fig = figure('Units', 'centimeters', 'Position', [2 2 30 18], 'Color', 'w');
t = tiledlayout(2, 6, "TileSpacing", "compact", "Padding", "loose"); theme(fig,'light');
dx = 0.1; dy = 0.025;
axisFontName = 'Times New Roman';
axisFontSize = 14;
labelFontSize = 14;
titleFontSize = 14;
legendFontSize = 14;
expectedResponseLineWidth = 1.8;
computedResponseLineWidth = 0.45;
computedResponseColor = [0.90 0 0];
exportFilename = 'RRX_Fig1.png';
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

GNAax = ax;

% Consistent tick-label typography and significant-figure formatting.
mainAxes = [MNAshapeAx, MNAcurveAx, GNAshapeAx, GNAax];
set(mainAxes, 'FontName', axisFontName, 'FontSize', axisFontSize, 'TickDir', 'out');
for k = 1:numel(mainAxes)
    xtickformat(mainAxes(k), '%#.1g');
    ytickformat(mainAxes(k), '%#.1g');
end

% Tile titles and axis labels.
title(MNAshapeAx, 'MNA target', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(MNAshapeAx, '$w/t$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(MNAshapeAx, 'Normalised height', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(MNAcurveAx, 'MNA response', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(MNAcurveAx, '$|u|/t$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(MNAcurveAx, 'Load proportionality factor', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(GNAshapeAx, 'GNA target', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(GNAshapeAx, '$w/t$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(GNAshapeAx, 'Normalised height', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

title(GNAax, 'GNA response', ...
    'FontName', axisFontName, 'FontSize', titleFontSize);
xlabel(GNAax, '$|u|/t$', 'Interpreter', 'latex', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);
ylabel(GNAax, 'Load proportionality factor', ...
    'FontName', axisFontName, 'FontSize', labelFontSize);

% Keep the top/right borders, but show ticks only on the bottom/left.
allAxes = mainAxes;
for k = 1:numel(allAxes)
    addUntickedTopRightBorder(allAxes(k));
end

% Lossless, publication-quality PNG export.
drawnow;
exportgraphics(fig, exportFilename, 'Resolution', exportResolution, 'BackgroundColor', 'white');


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
