 % ============================================================
% MSc. Diego Arias Cazco
% ECP, ELCC and Firm Capacity -- Annual 8760-Hour Case Study
% Ecuador SNI 2025 | 500, 800, 1200 y 2000 MW Aggregated PV Block
% IEEE ETCM 2026
%Esta simulación contiene la data solar real  Promedio de todo el Ecuador. 
% ============================================================
clc; clear; close all;
tic
%% ============================================================
% 1. LOAD ANNUAL DEMAND DATA (8760 h)
%% ============================================================
if exist('Demanda_2025_8760.mat', 'file')
    load('Demanda_2025_8760.mat', 'Demanda_total');
    Demand_8760 = Demanda_total(:);          % ensure column vector
else
    error(['File Demanda_2025_8760.mat not found. ' ...
           'Run the data consolidation script first.']);
end
T_total = length(Demand_8760);              % must be 8760

%% ============================================================
% 2. REAL ECUADOR SOLAR PROFILE (NSRDB 2024)
%    Spatial average of 13,017 points across Ecuador SNI
%    Replaces the synthetic sinusoidal profile entirely.
% ============================================================
P_nom_PV = 500;               % [MW] -- aggregated SNI PV block

% Load real NSRDB-derived CF profile (8760 x 1, values in [0,1])
nsrdb_file = 'CF_Ecuador_NSRDB_8760.mat';
if exist(nsrdb_file, 'file')
    loaded = load(nsrdb_file, 'CF_8760');
    CF_8760 = loaded.CF_8760(:);             % ensure column vector
    if length(CF_8760) ~= T_total
        error(['CF_Ecuador_NSRDB_8760.mat has %d rows, expected %d. ' ...
               'Verify the NSRDB processing script output.'], ...
              length(CF_8760), T_total);
    end
    fprintf('=== Solar Profile loaded from NSRDB (real data) ===\n');
else
    error(['File %s not found in the working directory.\n' ...
           'Run the NSRDB processing script first to generate it.'], ...
          nsrdb_file);
end

PV_hourly_8760 = P_nom_PV * CF_8760;        % [MW], 8760 x 1

% --- Compute monthly averages for reporting and validation ---
days_pm      = [31,28,31,30,31,30,31,31,30,31,30,31];
month_names  = {'Jan','Feb','Mar','Apr','May','Jun', ...
                'Jul','Aug','Sep','Oct','Nov','Dec'};
CF_monthly_real = zeros(1, 12);
idx_m = 0;
for m = 1:12
    n_h = days_pm(m) * 24;
    CF_monthly_real(m) = mean(CF_8760(idx_m+1 : idx_m+n_h));
    idx_m = idx_m + n_h;
end

fprintf('Annual average CF  : %.4f  (%.1f%%)\n', mean(CF_8760), mean(CF_8760)*100);
fprintf('Peak PV output     : %.1f MW\n',  max(PV_hourly_8760));
fprintf('Annual PV energy   : %.0f MWh\n', sum(PV_hourly_8760));
fprintf('Monthly avg CF [p.u.]:\n');
for m = 1:12
    fprintf('  %s : %.4f\n', month_names{m}, CF_monthly_real(m));
end
fprintf('\n');

%% ============================================================
% 3. DATA CONSISTENCY CHECK
%% ============================================================
fprintf('=== System Data Consistency ===\n');
fprintf('Demand vector size    : %d x %d\n', size(Demand_8760,1), size(Demand_8760,2));
fprintf('PV vector size        : %d x %d\n', size(PV_hourly_8760,1), size(PV_hourly_8760,2));
fprintf('Peak annual demand    : %.2f MW\n', max(Demand_8760));
fprintf('Min  annual demand    : %.2f MW\n\n', min(Demand_8760));

%% ============================================================
% 4. COPT CONSTRUCTION via Recursive Convolution  (Phase A)
%    Ecuador SNI 2025 -- Disaggregated generation park
%    Format: [Capacity_MW, Availability_p]
%% ============================================================
GenPark = [
    % --- HYDROELECTRIC ---
    1245, 0.80;   % Coca Codo Sinclair
    1070, 0.73;   % Paute-Molino
     400, 0.73;   % Sopladora
     140, 0.97;   % Agoyán
     154, 0.98;   % Marcel Laniado de Wind
     135, 0.73;   % Mazar
     190, 0.97;   % San Francisco
     150, 0.97;   % Delsitanisagua
    1900, 0.90;   % Other minor hydro (aggregate)
    % --- THERMAL ---
     387, 0.96;   % TermoPichincha
     220, 0.96;   % Termogas Machala
     250, 0.90;   % Elecaustro
     189, 0.91;   % TermoManabí
     105, 0.90;   % Termoesmeraldas
     133, 0.93;   % Trinitaria
     104, 0.93;   % Gonzalo Zevallos
      91, 0.90;   % Jaramijó
    1795, 0.85;   % Other thermal blocks (SNI aggregate)
    % --- BIOMASS + BIOGAS ---
     159, 0.90;   % Biomass and Biogas
];

P_inst = sum(GenPark(:,1));    % Total conventional installed [MW]

% Recursive convolution (execute once, offline)
COPT_fail = 0;
COPT_prob = 1;
for u = 1:size(GenPark, 1)
    Pu = GenPark(u,1);  pu = GenPark(u,2);  qu = 1 - pu;
    Cap_tmp  = [COPT_fail;         COPT_fail + Pu];
    Prob_tmp = [COPT_prob * pu;    COPT_prob * qu];
    [COPT_fail, ~, ig] = unique(Cap_tmp);
    COPT_prob = accumarray(ig, Prob_tmp);
end
P_disp = P_inst - COPT_fail;  % Available-capacity states [MW]
                                % unique and sorted (P_inst to 0)

fprintf('=== COPT Summary ===\n');
fprintf('Total conventional installed : %.0f MW\n', P_inst);
fprintf('Unique COPT states           : %d\n\n', length(COPT_fail));

%% ============================================================
% 5. SCENARIO (BASE): Annual Reliability -- No PV  (Phase B)
%% ============================================================
LOLP_base = zeros(T_total, 1);
for t = 1:T_total
    deficit = P_disp < Demand_8760(t);
    if any(deficit)
        LOLP_base(t) = sum(COPT_prob(deficit));
    end
end
LOLE_base = sum(LOLP_base);

fprintf('=== Scenario 1 (Baseline, No PV) ===\n');
fprintf('LOLE Base : %.4f  h/yr\n\n', LOLE_base);



%% ============================================================
% FIGURA 1 CORREGIDA -- LDC + NLDC + LOLP Sensitivity (Línea Sin Círculos)
%% ============================================================
 
[Demand_LDC, idx_sort] = sort(Demand_8760, 'descend');
LOLP_LDC = LOLP_base(idx_sort);
 
% Compute Net Load Duration Curves for each PV scenario
% Each is sorted INDEPENDENTLY (descending), same as the base LDC
Demand_net_500  = Demand_8760 - CF_8760 * 500;
Demand_net_800  = Demand_8760 - CF_8760 * 800;
Demand_net_1200 = Demand_8760 - CF_8760 * 1200;
Demand_net_2000 = Demand_8760 - CF_8760 * 2000; 
 
NLDC_500  = sort(Demand_net_500,  'descend');
NLDC_800  = sort(Demand_net_800,  'descend');
NLDC_1200 = sort(Demand_net_1200, 'descend');
NLDC_2000 = sort(Demand_net_2000, 'descend'); 
 
figure('Color','w','Units','inches','Position',[1 1 6.5 4.5]);
 
yyaxis left
% Base LDC
p1 = plot(Demand_LDC, 'Color',[0 0.45 0.74], ...
          'LineWidth',2.5, 'LineStyle','-', 'DisplayName','Demand (Base LDC)');
hold on
 
% Net LDC per scenario
p2 = plot(NLDC_500, 'Color',[0.47 0.67 0.19], ...
          'LineWidth',1.8,'LineStyle','--','DisplayName','Net Demand — 500 MW PV');
p3 = plot(NLDC_800, 'Color',[0.85 0.33 0.10], ...
          'LineWidth',1.5,'LineStyle','-.','DisplayName','Net Demand — 800 MW PV');
p4 = plot(NLDC_1200,'Color',[0.93 0.69 0.13], ...
          'LineWidth',1.5,'LineStyle',':','DisplayName','Net Demand — 1200 MW PV');
      
% Corrección estricta: se añade 'Marker', 'none' para anular cualquier círculo heredado
p5 = plot(NLDC_2000,'Color',[0.49 0.18 0.56], ...
          'LineWidth',1.1,'LineStyle','-', 'Marker','none', ...
          'DisplayName','Net Demand — 2000 MW PV'); 
 
ylabel('Electrical System Demand [MW]','FontWeight','bold','FontSize',11)
ylim([min(NLDC_2000)*0.90, max(Demand_8760)*1.10])
ax = gca;  ax.YColor = [0 0.45 0.74];
 
% Shade the area between base LDC and 500 MW NLDC
% to visually highlight the PV displacement
fill([1:T_total, T_total:-1:1], ...
     [Demand_LDC', fliplr(NLDC_500')], ...
     [0.47 0.67 0.19], 'FaceAlpha',0.06, 'EdgeColor','none', ...
     'HandleVisibility','off')
 
yyaxis right
p_lolp = area(LOLP_LDC,'FaceColor',[0.85 0.33 0.10],'EdgeColor',[0.85 0.33 0.10],...
              'FaceAlpha',0.15,'LineWidth',1.2,'DisplayName','LOLP (Baseline)');
ylabel('Loss of Load Probability (LOLP)','FontWeight','bold','FontSize',11)
ylim([0, max(LOLP_base)*1.2])
ax.YColor = [0.85 0.33 0.10];
 
grid on
set(gca,'GridLineStyle',':','GridAlpha',0.5,'FontSize',10)
xlim([1 T_total])
xlabel('Hours Sorted by Load Level','FontWeight','bold','FontSize',11)
title('Load Duration Curves and Probabilistic Risk Profile',...
      'FontSize',12,'FontWeight','bold')
 
annotation('textbox',[0.54 0.82 0.30 0.07],...
    'String', sprintf('LOLE_{base} = %.4f  h/yr', LOLE_base),...
    'FitBoxToText','on','BackgroundColor','w',...
    'EdgeColor',[0.5 0.5 0.5],'FontSize',9,'FontWeight','bold')
 
% Leyenda actualizada con la curva corregida
legend([p1 p2 p3 p4 p5 p_lolp], 'Location','northeast','FontSize',8.5,'NumColumns',2)
box on;  hold off


%set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
%exportgraphics(gcf,'LDC_NLDC_LOLP.pdf','ContentType','vector');

%% ============================================================
% 7B. PV PENETRATION SENSITIVITY ANALYSIS
% ============================================================

PV_cases = [500, 800, 1200, 2000];

colors   = [0    0.45 0.74;    % blue   -- 500  MW
            0.85 0.32 0.09;    % orange -- 800  MW
            0.93 0.69 0.13;    % amber  -- 1200 MW
            0.49 0.18 0.56];   % purple -- 2000 MW
step_s   = 4;                         % MW sweep step (interpolation
                                      % restores sub-step precision)

ECP_results    = zeros(size(PV_cases));
ELCC_results   = zeros(size(PV_cases));
LOLE_solar_vec = zeros(size(PV_cases));

% ---- Initialize figures ----
fig_ECP  = figure('Color','w','Units','inches','Position',[1 1 6 4.5]);
hold on;  grid on;  grid minor;  box on
title('ECP Sensitivity — Solar PV Penetration', ...
      'FontSize',12,'FontWeight','bold')
xlabel('Additional Conventional Generator Capacity [MW]', ...
       'FontWeight','bold','FontSize',11)
ylabel('LOLE [hours/year]','FontWeight','bold','FontSize',11)
set(gca,'FontSize',10,'GridAlpha',0.4)

fig_ELCC = figure('Color','w','Units','inches','Position',[8 1 6 4.5]);
hold on;  grid on;  grid minor;  box on
title('ELCC Sensitivity — Solar PV Penetration', ...
      'FontSize',12,'FontWeight','bold')
xlabel('\DeltaL — Additional System Load [MW]', ...
       'FontWeight','bold','FontSize',11)
ylabel('LOLE [hours/year]','FontWeight','bold','FontSize',11)
set(gca,'FontSize',10,'GridAlpha',0.4)

% ============================================================
% Main loop over PV penetration scenarios
% ============================================================
for i = 1:length(PV_cases)

    P_nom_i      = PV_cases(i);
    PV_hourly_i  = CF_8760 * P_nom_i;        % uses same CF profile
    Demand_net_i = Demand_8760 - PV_hourly_i;

    % --- LOLE with this PV block (net demand approach) -------
    LOLP_solar_i = zeros(T_total, 1);
    for t = 1:T_total
        deficit = P_disp < Demand_net_i(t);
        if any(deficit)
            LOLP_solar_i(t) = sum(COPT_prob(deficit));
        end
    end
    LOLE_solar_i      = sum(LOLP_solar_i);
    LOLE_solar_vec(i) = LOLE_solar_i;

    % ==========================================================
    % ECP SWEEP  (target: match LOLE with PV)
    % ==========================================================
%% ECP sweep con vectorización + early break
%% ECP SWEEP  -- CORRECTED
P_test_i   = 0 : step_s : P_nom_i;
LOLE_ecp_i = zeros(size(P_test_i));
% idx_ecp = length(P_test_i);   <-- ELIMINAR esta línea

for k = 1:length(P_test_i)
    P_disp_k      = P_disp + P_test_i(k);
    LOLE_ecp_i(k) = sum(COPT_prob' * double(P_disp_k < Demand_8760'));
    % ELIMINAR el bloque if/break completo:
    % if LOLE_ecp_i(k) <= LOLE_solar_i
    %     idx_ecp = k;
    %     break
    % end
end
% Mantener solo este find() -- el de afuera del loop
idx_ecp = find(LOLE_ecp_i <= LOLE_solar_i, 1, 'first');

if isempty(idx_ecp)
    ECP_i = 0;
    warning('ECP not found for PV = %d MW', P_nom_i);
elseif idx_ecp > 1
    x0 = P_test_i(idx_ecp-1);  y0 = LOLE_ecp_i(idx_ecp-1);
    x1 = P_test_i(idx_ecp);    y1 = LOLE_ecp_i(idx_ecp);
    ECP_i = x0 + (LOLE_solar_i - y0) * (x1 - x0) / (y1 - y0);
else
    ECP_i = P_test_i(1);
end
ECP_results(i) = ECP_i;

    % ==========================================================
    % ELCC SWEEP  (target: restore base LOLE)
    % ==========================================================
  %% ELCC SWEEP  -- CORRECTED
Delta_L_i   = 0 : step_s : P_nom_i;
LOLE_elcc_i = zeros(size(Delta_L_i));
% idx_elcc = length(Delta_L_i);  <-- ELIMINAR esta línea

for k = 1:length(Delta_L_i)
    Demand_k       = Demand_net_i + Delta_L_i(k);
    LOLE_elcc_i(k) = sum(COPT_prob' * double(P_disp < Demand_k'));
    % ELIMINAR el bloque if/break completo:
    % if LOLE_elcc_i(k) >= LOLE_base
    %     idx_elcc = k;
    %     break
    % end
end
% Mantener solo este find()
idx_elcc = find(LOLE_elcc_i >= LOLE_base, 1, 'first');

if isempty(idx_elcc)
    ELCC_i = 0;
    warning('ELCC not found for PV = %d MW', P_nom_i);
elseif idx_elcc > 1
    x0 = Delta_L_i(idx_elcc-1);  y0 = LOLE_elcc_i(idx_elcc-1);
    x1 = Delta_L_i(idx_elcc);    y1 = LOLE_elcc_i(idx_elcc);
    ELCC_i = x0 + (LOLE_base - y0) * (x1 - x0) / (y1 - y0);
else
    ELCC_i = Delta_L_i(1);
end
ELCC_results(i) = ELCC_i;


    fprintf('PV %4d MW | LOLE_solar = %6.3f h/yr | ECP = %6.2f MW | ELCC = %6.2f MW\n', ...
            P_nom_i, LOLE_solar_i, ECP_i, ELCC_i);

    % ==========================================================
    % ECP FIGURE
    % ==========================================================
    figure(fig_ECP)

    % LOLE sweep curve — ECP value included in legend label (avoids
    % floating text overlapping lines, consistent with ELCC figure)
    plot(P_test_i, LOLE_ecp_i, 'Color',colors(i,:), 'LineWidth',2, ...
         'DisplayName', sprintf('PV %d MW  (ECP = %.1f MW)', P_nom_i, ECP_i))

    % Horizontal reference at LOLE_solar_i for this scenario
    yline(LOLE_solar_i, '--', 'Color',colors(i,:), 'LineWidth',1.2, ...
          'HandleVisibility','off')

    % Vertical drop to x-axis from INTERPOLATED ECP marker
    plot([ECP_i ECP_i], [0 LOLE_solar_i], ':', 'Color',colors(i,:), ...
         'LineWidth',1.0, 'HandleVisibility','off')

    % Marker exactly at INTERPOLATED crossing point on target line
    plot(ECP_i, LOLE_solar_i, 'ko', 'MarkerFaceColor',colors(i,:), ...
         'MarkerSize',7, 'HandleVisibility','off')

    % ==========================================================
    % ELCC FIGURE
    % ==========================================================
    figure(fig_ELCC)

    % LOLE sweep curve (label includes ELCC value -- avoids crowded text)
    plot(Delta_L_i, LOLE_elcc_i, 'Color',colors(i,:), 'LineWidth',2, ...
         'DisplayName', sprintf('PV %d MW  (ELCC = %.1f MW)', P_nom_i, ELCC_i))

    % Marker exactly at INTERPOLATED crossing point on target line
    plot(ELCC_i, LOLE_base, 'ko', 'MarkerFaceColor',colors(i,:), ...
         'MarkerSize',7, 'HandleVisibility','off')

    % Vertical drop to x-axis from INTERPOLATED ELCC marker
    plot([ELCC_i ELCC_i], [0 LOLE_base], ':', 'Color',colors(i,:), ...
         'LineWidth',1.0, 'HandleVisibility','off')

end   % end PV_cases loop

% ---- Finalize ECP figure ----
figure(fig_ECP)
legend('Location','northeast','FontSize',10)
hold off

%set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
%exportgraphics(gcf,'ECP8760.pdf','ContentType','vector');

% ---- Finalize ELCC figure ----
figure(fig_ELCC)
% Single horizontal baseline (same for all scenarios)
yline(LOLE_base, 'k-', 'LineWidth',1.5, ...
      'DisplayName', sprintf('Target LOLE  (base = %.2f h/yr)', LOLE_base))
legend('Location','northwest','FontSize',10)
hold off

%set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
%exportgraphics(gcf,'ELCC8760.pdf','ContentType','vector');

% ============================================================
% SUMMARY TABLE
% ============================================================
fprintf('\n=== SENSITIVITY ANALYSIS RESULTS ===\n');
Results_sens = table( ...
    PV_cases(:), ...
    LOLE_solar_vec(:), ...
    ECP_results(:), ...
    ELCC_results(:), ...
    100 * ECP_results(:)  ./ PV_cases(:), ...
    100 * ELCC_results(:) ./ PV_cases(:), ...
    'VariableNames', ...
    {'PV_MW','LOLE_solar_hyr','ECP_MW','ELCC_MW','ECP_CC_pct','ELCC_CC_pct'});
disp(Results_sens)
toc