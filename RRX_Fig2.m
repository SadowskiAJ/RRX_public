close all

% RRX Figure 2: enlarged GNA equilibrium paths and highlighted GNA2 families.
% Run S1_Build, S2_Frechet and S3_ClusterAnalysis first.
% Preserve the analysis workspace and the family colours used by RRX_Fig4.
requiredVariables = {'RRX_data', 'unique_GNA1', 'unique_GNA2', ...
                     'unique_GNA3', 'GNA2_Clusters'};
for i = 1:numel(requiredVariables)
    assert(exist(requiredVariables{i}, 'var') == 1, ...
        'Run S1_Build, S2_Frechet and S3_ClusterAnalysis before RRX_Fig2 (missing %s).', ...
        requiredVariables{i});
end
families = GNA2_Clusters;
referenceFile = 'ReferenceResults.xlsx';
GNAref_path = abs(readmatrix(referenceFile, 'Range', 'M13:N113'));
GNAcurves = [uniqueLPFUendCurves(RRX_data, unique_GNA1, 'cGNA1_Block'), ...
             uniqueLPFUendCurves(RRX_data, unique_GNA2, 'cGNA2_Block'), ...
             uniqueLPFUendCurves(RRX_data, unique_GNA3, 'cGNA3_Block')];

% Fixed physical size gives reproducible exports independent of screen size.
% At 180 mm print width the tick labels are 12 pt.
figureWidth = 18; figureHeight = 12;
fontName = 'Times New Roman';
axisFontSize = 12; labelFontSize = 14; legendFontSize = 12;
expectedLineWidth = 1.8; computedLineWidth = 0.8; familyLineWidth = 2.2;
computedColour = [0.90 0 0];
familyStyles = {'-', '--', '-.'}; % Also distinguish families in monochrome.
shellThickness = 1; % Benchmark thickness, in the same length units as u.
zoomX = [0.4 1.0]; zoomY = [0.68 1.02]; % x limits are |u|/t.
exportFilename = 'RRX_Fig2.png';
% Lossless raster export at twice the former resolution in each direction.
exportResolution = 1200;

fig = figure('Units', 'centimeters', ...
    'Position', [2 2 figureWidth figureHeight], 'Color', 'w');
theme(fig, 'light');
t = tiledlayout(fig, 1, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(t);
hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
set(ax, 'FontName', fontName, 'FontSize', axisFontSize, ...
    'TickDir', 'out', 'LineWidth', 0.9, 'Layer', 'bottom', ...
    'XGrid', 'on', 'YGrid', 'on', ...
    'GridColor', [0.55 0.55 0.55], 'GridAlpha', 0.65, 'GridLineStyle', '-', ...
    'XMinorGrid', 'on', 'YMinorGrid', 'on', ...
    'MinorGridColor', [0.65 0.65 0.65], 'MinorGridAlpha', 0.30, ...
    'MinorGridLineStyle', ':');

% Retain all the original inset histories, in their recorded point order.
for i = 1:numel(GNAcurves)
    h = plot(ax, abs(GNAcurves{i}(:,2))/shellThickness, GNAcurves{i}(:,1), ...
        '-', 'Color', computedColour, 'LineWidth', computedLineWidth);
    if i == 1; computedLine = h; end
end
familyLines = gobjects(numel(families.representatives), 1);
for k = 1:numel(familyLines)
    block = RRX_data(families.representatives(k)).cGNA2_Block;
    familyLines(k) = plot(ax, abs(block.vdU)/shellThickness, block.vdLPF, ...
        'Color', families.colours(k,:), 'LineWidth', familyLineWidth, ...
        'LineStyle', familyStyles{mod(k-1, numel(familyStyles))+1});
end
% Smooth only the reference's display: PCHIP passes through its samples and
% preserves their monotonic shape without overshoot. Remove repeated abscissae
% in the spreadsheet's padded tail; never extrapolate beyond the reference.
referencePoints = GNAref_path(all(isfinite(GNAref_path), 2), :);
[referenceU, firstOccurrence] = unique(referencePoints(:,2), 'stable');
referenceLPF = referencePoints(firstOccurrence, 1);
assert(numel(referenceU) >= 2 && all(diff(referenceU) > 0), ...
    'Expected reference displacement must increase monotonically.');
smoothU = unique([referenceU; linspace(referenceU(1), referenceU(end), 2001).']);
smoothLPF = interp1(referenceU, referenceLPF, smoothU, 'pchip');
% Draw the expected path last so that agreement remains visible.
expectedLine = plot(ax, smoothU/shellThickness, smoothLPF, ...
    'k--', 'LineWidth', expectedLineWidth);
xlim(ax, zoomX); ylim(ax, zoomY);
xticks(ax, 0.4:0.1:1.0); yticks(ax, 0.7:0.05:1.0);
ax.XAxis.MinorTickValues = 0.45:0.1:0.95;
ax.YAxis.MinorTickValues = 0.725:0.05:0.975;
xtickformat(ax, '%.1f'); ytickformat(ax, '%.2f');
xlabel(ax, 'Loaded-edge meridional shortening $|u|/t$', ...
    'Interpreter', 'latex', 'FontSize', labelFontSize);
ylabel(ax, 'Load proportionality factor', ...
    'FontName', fontName, 'FontSize', labelFontSize);
familyNames = cellfun(@(name) ['GNA2 ' name], families.names(:), ...
    'UniformOutput', false);
legend(ax, [expectedLine; computedLine; familyLines], ...
    [{'Expected fundamental path'; 'Computed GNA1--3'}; familyNames], ...
    'Location', 'southeast', 'Interpreter', 'latex', ...
    'FontSize', legendFontSize, 'AutoUpdate', 'off', 'Box', 'on');
addUntickedTopRightBorder(ax);
drawnow;
exportgraphics(fig, exportFilename, 'Resolution', exportResolution, ...
    'BackgroundColor', 'white');

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
