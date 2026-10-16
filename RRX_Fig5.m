close all

% RRX Figure 5 generator: distributions of recorded peak load proportionality factors.
%
% Run S1_Build first. All submissions count, including repeated histories.
% Peaks are max(LPF), not max(abs(LPF)); reversed loading is not a new peak.
% RR3 convention: boxes Q1--Q3, red median, whiskers to minimum and maximum.
assert(exist('RRX_data', 'var') == 1 && ~isempty(RRX_data), ...
    'Run S1_Build before RRX_Fig5.');
assert(peakLPF([0; 1; 0.8; -2.5]) == 1, ...
    'Peak extraction must retain the sign of the load.');

analysisNames = {'MNA', 'GNA1', 'GNA2', 'GNA3'};
nSubmissions = numel(RRX_data);
peakLoads = zeros(nSubmissions, numel(analysisNames));
for j = 1:numel(analysisNames)
    blockField = ['c' analysisNames{j} '_Block'];
    for i = 1:nSubmissions
        peakLoads(i,j) = peakLPF(RRX_data(i).(blockField).vdLPF);
    end
end
assert(all(isfinite(peakLoads(:))) && all(peakLoads(:) > 0), ...
    'Each analysis must have a finite, positive recorded peak.');

quartiles = prctile(peakLoads, [25 50 75], 1);
peakMedians = quartiles(2,:);
dispersionCoefficients = 100 * (quartiles(3,:) - quartiles(1,:)) ./ peakMedians;
peakSummary = table(string(analysisNames(:)), repmat(nSubmissions,4,1), ...
    min(peakLoads,[],1).', quartiles(1,:).', peakMedians.', ...
    quartiles(3,:).', max(peakLoads,[],1).', dispersionCoefficients.', ...
    'VariableNames', {'Analysis','N','Minimum','Q1','Median','Q3','Maximum','DC_percent'});
disp(peakSummary);
fprintf('Recorded peak LPF; DC = 100*(Q3-Q1)/median. All submissions retained.\n');
for j = 1:numel(analysisNames)
    fprintf('%-4s n=%d, min=%.10f, median=%.10f, max=%.10f, DC=%.8g%%\n', ...
        analysisNames{j}, nSubmissions, min(peakLoads(:,j)), ...
        peakMedians(j), max(peakLoads(:,j)), dispersionCoefficients(j));
end

% Match the RR3 canvas and screen-density scaling.
REF_W = 3977; REF_H = 2150;
uiScale = 144/get(groot,'ScreenPixelsPerInch');
FS = 24*uiScale; LABEL_FS = 28*uiScale;
MS = 6*uiScale; STAT_FS = 18*uiScale;
fig = figure('Units','pixels', 'Position',[20 20 REF_W REF_H], ...
    'WindowState','maximized', 'Color','w');
theme(fig,'light');
layout = tiledlayout(fig,1,1,'TileSpacing','tight','Padding','compact');
ax = nexttile(layout);
boxplot(ax, peakLoads, 'Positions',(1:4)+0.12, 'Widths',0.25, ...
    'PlotStyle','traditional', 'Colors',[0 0.25 0.65], ...
    'Symbol','o', 'Whisker',Inf);
hold(ax,'on');
set(findobj(ax,'Type','Line'),'LineWidth',2*uiScale);
set(findobj(ax,'Tag','Median'),'Color',[0.8 0 0]);

% Fixed offsets show repeated observations without changing the random state.
pointOffsets = linspace(-0.055,0.055,nSubmissions).';
for j = 1:numel(analysisNames)
    points = plot(ax, j-0.23+pointOffsets, peakLoads(:,j), 'o', ...
        'LineStyle','none', 'MarkerSize',MS, 'LineWidth',uiScale, ...
        'MarkerEdgeColor',[0.25 0.25 0.25], 'MarkerFaceColor',[0.8 0.8 0.8]);
    if j == 1; submissionHandle = points; end
end
referenceHandle = yline(ax,1,'--','Color',0.7*ones(1,3),'LineWidth',3);
uistack(referenceHandle,'bottom');

dataLow = min([peakLoads(:); 1]);
dataHigh = max([peakLoads(:); 1]);
dataSpan = max(dataHigh-dataLow,0.005);
plotLimits = [dataLow-0.15*dataSpan, dataHigh+0.35*dataSpan];
xlim(ax,[0.5 4.5]); ylim(ax,plotLimits);
set(ax, 'XTick',1:4, 'XTickLabel',analysisNames, ...
    'TickLabelInterpreter','latex', 'FontName','Times New Roman', ...
    'FontSize',FS, 'TickDir','out', 'LineWidth',uiScale, ...
    'XGrid','off', 'YGrid','on', 'YMinorGrid','off', ...
    'GridColor',[0.65 0.65 0.65], 'GridAlpha',0.25, 'Layer','bottom');
ax.YAxis.Exponent = 0;
ytickformat(ax,'%.3f');
ylabel(ax,'Peak load proportionality factor $\lambda_{\max}$', ...
    'Interpreter','latex','FontSize',LABEL_FS);

for j = 1:numel(analysisNames)
    text(ax,j, dataHigh+0.29*dataSpan, sprintf('$n=%d$',nSubmissions), ...
        'Interpreter','latex','FontSize',STAT_FS,'HorizontalAlignment','center');
    text(ax,j, dataHigh+0.20*dataSpan, ...
        sprintf('$\\tilde{\\lambda}_{\\max}=%.5f$',peakMedians(j)), ...
        'Interpreter','latex','FontSize',STAT_FS,'HorizontalAlignment','center');
    text(ax,j, dataHigh+0.11*dataSpan, ...
        sprintf('$\\mathrm{DC}=%.3g\\,\\%%$',dispersionCoefficients(j)), ...
        'Interpreter','latex','FontSize',STAT_FS,'HorizontalAlignment','center');
end
legend(ax,[submissionHandle referenceHandle], ...
    {'Individual submissions','Reference load $\lambda=1$'}, ...
    'Interpreter','latex','FontSize',20*uiScale,'Location','southoutside', ...
    'Orientation','horizontal','Box','off','AutoUpdate','off');

box(ax,'on');
drawnow;
% Fix print width to avoid an enormous raster from the full-screen canvas.
exportgraphics(fig,fullfile(fileparts(mfilename('fullpath')),'RRX_Fig5.png'), ...
    'Units','centimeters','Width',18,'Resolution',1200, ...
    'BackgroundColor','white');

function peak = peakLPF(lpf)
    assert(isnumeric(lpf) && isvector(lpf) && ~isempty(lpf) ...
        && all(isfinite(lpf(:))), 'Peak LPF requires a complete, finite load history.');
    peak = max(lpf);
end
