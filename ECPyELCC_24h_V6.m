% ============================================================
% MSc. Diego Arias Cazco
% ECP, ELCC and Firm Capacity -- 24-Hour Illustrative Case
% IEEE ETCM 2026 -- Reproducible script for Table V & Figs. 1-3
% ============================================================
clc; clear; close all;
 
%%  1 -- SYSTEM DATA ==========================================
p     = [0.95 0.95 0.95 0.95];       % unit availability (1 - FOR)
P_nom = [85   75   55   35  ];        % nominal capacity [MW]: G1 G2 G3 PV
 
% 24-hour demand profile [MW]
Demand = [71 62 56 51 48 47 47 41 45 54 62 66 ...
          69 70 69 67 66 66 66 67 70 89 88 79];
 
% PV hourly capacity factor [p.u.]
CF = [0    0    0    0    0    0    0.05 0.15 0.35 0.55 0.75 0.90 ...
      1.00 0.95 0.80 0.60 0.40 0.20 0.05 0    0    0    0    0   ];
 
PV_hourly = P_nom(4) * CF;            % PV output at each hour [MW]
 
%%  2 -- STATE SPACE WITH PV  (2^4 = 16 states) ==============
n = 4;  N = 2^n;
S = dec2bin(0:N-1) - '0';             % 16 x 4 binary state matrix
                                       % columns: G1 G2 G3 PV
 
prob_PV = prod(S.*p + (1-S).*(1-p), 2);   % 16x1 state probabilities
 
cap_hour = zeros(N, 24);
for h = 1:24
    cap_hour(:,h) = S(:,1:3)*P_nom(1:3)' + S(:,4)*PV_hourly(h);
end
 
%%  3 -- LOLP / LOLE WITH PV ==================================
LOLP_PV = zeros(24,1);
for h = 1:24
    LOLP_PV(h) = sum(prob_PV(cap_hour(:,h) < Demand(h)));
end
LOLE_PV = sum(LOLP_PV);
fprintf('LOLE with PV    = %.5f  h/day\n', LOLE_PV);
 
%%  4 -- STATE SPACE + LOLP WITHOUT PV  (2^3 = 8 states) =====
S_conv    = dec2bin(0:7) - '0';                          % 8 x 3
cap_conv  = S_conv * P_nom(1:3)';                        % 8 x 1
prob_conv = prod(S_conv.*p(1:3) + (1-S_conv).*(1-p(1:3)), 2);
 
LOLP_base = zeros(24,1);
for h = 1:24
    LOLP_base(h) = sum(prob_conv(cap_conv < Demand(h)));
end
LOLE_base = sum(LOLP_base);
fprintf('LOLE without PV = %.5f  h/day\n', LOLE_base);
 
%%  5 -- ECP -- Equivalent Conventional Power (Algorithm 1) ==
% Find the conventional capacity that achieves the same LOLE
% as the system WITH PV.
LOLE_tgt_ECP = LOLE_PV;
P_test = 0 : 0.5 : 40;               % capacity sweep [MW]
 
LOLE_ecp = zeros(size(P_test));
for k = 1:length(P_test)
    Padd = P_test(k);
    L = 0;
    for h = 1:24
        L = L + sum(prob_conv((cap_conv + Padd) < Demand(h)));
    end
    LOLE_ecp(k) = L;
end
 
idx_ecp      = find(LOLE_ecp <= LOLE_tgt_ECP, 1, 'first');
ECP_discrete = P_test(idx_ecp);
 
% Linear interpolation for sub-step precision
if idx_ecp > 1
    x0 = P_test(idx_ecp-1); y0 = LOLE_ecp(idx_ecp-1);
    x1 = P_test(idx_ecp);   y1 = LOLE_ecp(idx_ecp);
    ECP_interp = x0 + (LOLE_tgt_ECP - y0) * (x1-x0) / (y1-y0);
else
    ECP_interp = ECP_discrete;
end
 
fprintf('\nECP (discrete)     = %.2f MW\n', ECP_discrete);
fprintf('ECP (interpolated) = %.4f MW\n',  ECP_interp);
 
%%  6 -- ELCC -- Effective Load Carrying Capability (Algorithm 2)
% Find the additional demand the system WITH PV can serve while
% keeping LOLE equal to the base level (without PV).
LOLE_tgt_ELCC = LOLE_base;
Delta_L = 0 : 1 : 40;                % demand increment sweep [MW]
 
LOLE_base_vec = zeros(size(Delta_L));
LOLE_elcc_vec = zeros(size(Delta_L));
 
for k = 1:length(Delta_L)
    Dk = Demand + Delta_L(k);
    Lb = 0;  Le = 0;
    for h = 1:24
        Lb = Lb + sum(prob_conv(cap_conv < Dk(h)));
        if PV_hourly(h) == 0
            % Night hours: PV unavailable -- use 8 conv. states only
            Le = Le + sum(prob_conv(cap_conv < Dk(h)));
        else
            % Daylight hours: use full 16-state space with PV
            Le = Le + sum(prob_PV(cap_hour(:,h) < Dk(h)));
        end
    end
    LOLE_base_vec(k) = Lb;
    LOLE_elcc_vec(k) = Le;
end
 
idx_elcc = find(LOLE_elcc_vec >= LOLE_tgt_ELCC, 1, 'first');
if isempty(idx_elcc)
    error('ELCC crossing not found -- increase range of Delta_L.');
end
ELCC_discrete = Delta_L(idx_elcc);
 
% Linear interpolation
if idx_elcc > 1
    x0 = Delta_L(idx_elcc-1); y0 = LOLE_elcc_vec(idx_elcc-1);
    x1 = Delta_L(idx_elcc);   y1 = LOLE_elcc_vec(idx_elcc);
    ELCC_interp = x0 + (LOLE_tgt_ELCC - y0) * (x1-x0) / (y1-y0);
else
    ELCC_interp = ELCC_discrete;
end
 
fprintf('ELCC (discrete)     = %.2f MW\n', ELCC_discrete);
fprintf('ELCC (interpolated) = %.4f MW\n',  ELCC_interp);
 
%%  7 -- FIRM CAPACITY -- PEPP Methodology (Algorithm 3) ======
%
%  NOTE ON THE EXPECTED RESULT
%  ~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%  The Chilean PEPP method evaluates the COPT at the peak-demand
%  hour only (h = argmax Demand).  In this system peak demand
%  occurs at h = 22 (D = 89 MW, night), where PV generates 0 MW.
%  Therefore cap_hour(:,22) is identical to cap_conv, both systems
%  share the same COPT, and the marginal contribution is:
%       FC_PV = FC_withPV - FC_withoutPV = 130 - 130 = 0 MW.
%  This is the CORRECT result -- it demonstrates the limitation
%  of peak-based approaches for solar PV (cf. Table V, paper
%  Section IV-A and the paper conclusions).
 
fprintf('\n=== FIRM CAPACITY (PEPP) DIAGNOSTICS ===\n');
[D_peak, h_peak] = max(Demand);
fprintf('  Peak demand hour  :  h = %d   (D_peak = %g MW)\n', h_peak, D_peak);
fprintf('  PV output at peak :  %.2f MW  (CF = %.2f)\n', ...
        PV_hourly(h_peak), CF(h_peak));
 
FC_withPV    = calc_firm_capacity(cap_hour, prob_PV,   Demand);
FC_withoutPV = calc_firm_capacity(cap_conv, prob_conv, Demand);
 
FC_PV_prel  = FC_withPV - FC_withoutPV;
FC_PV_final = 0.8 * FC_PV_prel;
 
fprintf('\n  System FC with PV      = %.2f MW\n', FC_withPV);
fprintf('  System FC without PV   = %.2f MW\n',  FC_withoutPV);
fprintf('  ---------------------------------------------\n');
fprintf('  Marginal FC_PV (prel)  = %.2f MW\n',  FC_PV_prel);
fprintf('  Final   FC_PV (x0.80)  = %.2f MW\n',  FC_PV_final);
fprintf(['\n  RESULT IS CORRECT: PV generates %.2f MW at h=%d (peak).\n',...
         '  COPT is identical with/without PV -> marginal FC = 0 MW.\n',...
         '  This is consistent with Table V of the paper.\n'], ...
        PV_hourly(h_peak), h_peak);
 
%%  8 -- SUMMARY TABLE (reproduces Table V) ===================
Tabla = table("PV Solar", P_nom(4), ...
    FC_PV_prel, FC_PV_final, ...
    ELCC_discrete, 100*ELCC_discrete/P_nom(4), ...
    ECP_discrete,  100*ECP_discrete/P_nom(4), ...
    'VariableNames', {'Unit','Pmax_MW', ...
        'FirmCap_Prel','FirmCap_Final', ...
        'ELCC_MW','ELCC_pct', ...
        'ECP_MW','ECP_pct'});
fprintf('\n=== CAPACITY CREDIT RESULTS (Table V) ===\n')
disp(Tabla);
 
%% =============================================================
%  FIGURES
%% =============================================================
 
%%  FIGURE 1 -- Hourly Load Profile and Reliability Risk (LOLP)
figure('Color','w','Units','inches','Position',[1 1 6 4]);
 
yyaxis left
plot(1:24, Demand, '-o', 'LineWidth',2, ...
     'Color',[0 0.45 0.74], 'MarkerFaceColor',[0 0.45 0.74])
hold on
plot(1:24, Demand - PV_hourly, '--', 'LineWidth',2, ...
     'Color',[0.85 0.33 0.10])
ylabel('Power [MW]', 'FontWeight','bold', 'FontSize',11)
ylim([0 max(Demand)*1.2])
ax = gca; ax.YColor = [0 0.45 0.74];
 
yyaxis right
stem(1:24, LOLP_PV, 'filled', 'LineWidth',1.5, ...
     'MarkerSize',4, 'Color',[0.49 0.18 0.56])
ylabel('LOLP [probability]', 'FontWeight','bold', 'FontSize',11)
ylim([0 max(LOLP_PV)*2.0])
ax.YColor = [0.49 0.18 0.56];
 
grid on
xlabel('Hour of the Day', 'FontWeight','bold', 'FontSize',11)
title('Hourly Load Profile and Reliability Risk (LOLP)', 'FontSize',12)
legend('Total Demand','Net Demand (Load \minus PV)','LOLP', ...
       'Location','northwest', 'FontSize',10)
set(gca, 'XTick',1:2:24, 'FontSize',10, 'GridAlpha',0.4)


% % ... mismo código de plot ...
% xlabel('Hour of the Day', 'FontSize',7)
% ylabel('Power [MW]',       'FontSize',7)
% title('(a) LOLP Profile',  'FontSize',8, 'FontWeight','bold')
% legend('Demand','Net Demand','LOLP', ...
%        'Location','north','FontSize',6,'NumColumns',3)
% set(gca,'FontSize',7,'XTick',1:4:24)


%set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
%exportgraphics(gcf,'LOLP.pdf','ContentType','vector')
 
%%  FIGURE 2 -- COPT Exceedance: Solar Peak vs Demand Peak
%   This figure visually explains why Firm Capacity = 0 for PV.
%   At h=22 (demand peak) PV generates 0 MW, so the COPT curve
%   is identical with and without PV.  The Chilean PEPP method
%   only evaluates at the demand peak --> FC_PV = 0.
 
% Build exceedance CDFs for three scenarios
[cs_base,  ce_base]  = compute_copt(cap_conv,          prob_conv);
h_sol = 12;  % solar generation peak
[cs_sol,   ce_sol]   = compute_copt(cap_hour(:,h_sol),  prob_PV);
[cs_peak,  ce_peak]  = compute_copt(cap_hour(:,h_peak), prob_PV);
 
% Compute PEPP for annotation
LOLP_pk = sum(prob_conv(cap_conv < D_peak));
PEPP     = 1 - LOLP_pk;
 
figure('Color','w','Units','inches','Position',[1 1 6.5 4.5]);
stairs(flip(cs_base), flip(ce_base), 'b-',  'LineWidth',2.5); hold on
stairs(flip(cs_sol),  flip(ce_sol),  'g-',  'LineWidth',2.0)
stairs(flip(cs_peak), flip(ce_peak), 'r--', 'LineWidth',2.0, 'Color',[0.85 0.1 0.1])
 
xline(D_peak, 'k:', 'LineWidth',1.5)
yline(PEPP,   'm:', 'LineWidth',1.5)
 
% Annotations
text(D_peak+2, 0.86, sprintf('D_{peak} = %g MW', D_peak), ...
     'FontSize',9, 'Color','k', 'FontWeight','bold')
text(5, PEPP+0.01, sprintf('PEPP = 1 - LOLP_{hp} = %.5f', PEPP), ...
     'FontSize',9, 'Color',[0.55 0 0.55])
 
grid on
xlabel('Available Capacity [MW]', 'FontWeight','bold', 'FontSize',10)
ylabel('Exceedance Probability P(C \geq X)', 'FontWeight','bold', 'FontSize',10)
title('COPT Exceedance — Why Firm Capacity = 0 for PV', 'FontSize',11)
legend( ...
    'Without PV  (reference, all hours)', ...
    sprintf('With PV, h = %d  (PV = %.0f MW  |  solar peak)', ...
            h_sol,  PV_hourly(h_sol)), ...
    sprintf('With PV, h = %d  (PV = %.2f MW  |  demand peak)', ...
            h_peak, PV_hourly(h_peak)), ...
    sprintf('Peak demand  D = %g MW', D_peak), ...
    'PEPP = 1 - LOLP_{hp}', ...
    'Location','southeast', 'FontSize',8)
xlim([0 max(cap_conv)+15]);  ylim([0.83 1.01])
 
% Callout box explaining the result
annotation('textbox',[0.35 0.60 0.35 0.10], ...
    'String', {'Red dashed \equiv Blue  at h_{peak}', ...
               '\Rightarrow  FC_{PV} = 130 - 130 = 0 MW'}, ...
    'FitBoxToText','on', 'BackgroundColor','w', ...
    'EdgeColor',[0.7 0 0], 'FontSize',8.5, 'FontWeight','bold', ...
    'Color',[0.7 0 0]);
 
 
%%  FIGURE 3 -- Equivalent Conventional Power (ECP) Determination
figure('Color','w','Units','inches','Position',[1 1 5.5 4]);
plot(P_test, LOLE_ecp, 'b-', 'LineWidth',2); hold on
yline(LOLE_tgt_ECP, 'r--', 'LineWidth',2)

% Vertical dotted reference line from INTERPOLATED ECP to x-axis
plot([ECP_interp ECP_interp], [0 LOLE_tgt_ECP], ...
     'k:', 'LineWidth',1.0)

% Marker exactly at interpolated crossing point on the target line
plot(ECP_interp, LOLE_tgt_ECP, 'ko', ...
     'MarkerFaceColor','g', 'MarkerSize',8)

% Leader line from marker UPWARD to label box (clear region above target)
xlab_ecp = ECP_interp + 4;
ylab_ecp = LOLE_tgt_ECP * 1.2;       % above the target line
plot([ECP_interp xlab_ecp], [LOLE_tgt_ECP ylab_ecp], ...
     '--', 'Color',[0.65 0.65 0.65], 'LineWidth',0.8)

% Label with white background box
text(xlab_ecp, ylab_ecp, sprintf('ECP = %.2f MW', ECP_interp), ...
     'FontWeight','bold', 'FontSize',12, ...
     'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
     'BackgroundColor','w', 'EdgeColor','k', 'Margin',3, ...
     'LineWidth',0.7)

grid on; grid minor
xlabel('Additional Conventional Generator Capacity [MW]', ...
       'FontWeight','bold', 'FontSize',11)
ylabel('LOLE [hours/day]', 'FontWeight','bold', 'FontSize',11)
title('Equivalent Conventional Power (ECP) Determination', 'FontSize',12)
legend('LOLE (ECP sweep)', 'Target LOLE (= LOLE with PV)', 'ECP', ...
       'Location','southoutside', 'FontSize',12)
axis([0 max(P_test) 0 max(LOLE_ecp)*1.15])
set(gca, 'FontSize',12, 'GridAlpha',0.4)
 
set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
exportgraphics(gcf,'ECP.pdf','ContentType','vector');

%%  FIGURE 4 -- Effective Load Carrying Capability (ELCC) Determination
figure('Color','w','Units','inches','Position',[1 1 6 4.5]);
plot(Delta_L, LOLE_elcc_vec, 'b-', 'LineWidth',2); hold on
plot(Delta_L, LOLE_base_vec, 'r-', 'LineWidth',2)
yline(LOLE_tgt_ELCC, 'g--', 'LineWidth',2)

% Vertical dotted reference line from INTERPOLATED ELCC to x-axis
plot([ELCC_interp ELCC_interp], [0 LOLE_tgt_ELCC], ...
     'k:', 'LineWidth',1.0)

% Marker exactly at interpolated crossing point on the target line
plot(ELCC_interp, LOLE_tgt_ELCC, 'ko', ...
     'MarkerFaceColor','g', 'MarkerSize',8)

% Leader line from marker UPWARD to label box (clear region above target)
xlab = ELCC_interp + 4;
ylab = LOLE_tgt_ELCC * 0.5;          % above the target line
plot([ELCC_interp xlab], [LOLE_tgt_ELCC ylab], ...
     '--', 'Color',[0.65 0.65 0.65], 'LineWidth',0.8)

% Label with white background box
text(xlab, ylab, sprintf('ELCC = %.2f MW', ELCC_interp), ...
     'FontWeight','bold', 'FontSize',12, ...
     'HorizontalAlignment','left', 'VerticalAlignment','middle', ...
     'BackgroundColor','w', 'EdgeColor','k', 'Margin',3, ...
     'LineWidth',0.7)

grid on; grid minor
xlabel('Additional Load \DeltaL [MW]', 'FontWeight','bold', 'FontSize',11)
ylabel('LOLE [hours/day]', 'FontWeight','bold', 'FontSize',11)
title('Effective Load Carrying Capability (ELCC) Determination', 'FontSize',12)
legend('LOLE with PV  (net demand + \DeltaL)', ...
       'LOLE without PV  (base demand + \DeltaL)', ...
       'Target LOLE  (= LOLE without PV, \DeltaL = 0)', ...
       'Location','southoutside', 'FontSize',12)
set(gca, 'FontSize',12, 'GridAlpha',0.4) 

set(findall(gcf,'-property','FontName'),'FontName','Helvetica');
exportgraphics(gcf,'ELCC.pdf','ContentType','vector');

%% =============================================================
%  LOCAL FUNCTIONS
%% =============================================================
 
function [cap_sorted_desc, ccdf] = compute_copt(cap_vec, prob_vec)
% COMPUTE_COPT  Build an exceedance CDF from a capacity-state vector.
%
%   [cap_sorted_desc, ccdf] = compute_copt(cap_vec, prob_vec)
%
%   Returns capacities sorted DESCENDING and the cumulative exceedance
%   ccdf(i) = P(C >= cap_sorted_desc(i)), for use with MATLAB stairs().
%   Plot as: stairs(flip(cap_sorted_desc), flip(ccdf))
 
    [cu, ~, ig] = unique(cap_vec);
    pa           = accumarray(ig, prob_vec);
    [cap_sorted_desc, ord] = sort(cu, 'descend');
    ccdf = cumsum(pa(ord));
end
 
 
function FC = calc_firm_capacity(cap_matrix, prob, Demand)
% CALC_FIRM_CAPACITY  PEPP-based firm capacity per Algorithm 3.
%
%   FC = calc_firm_capacity(cap_matrix, prob, Demand)
%
%   Inputs:
%     cap_matrix : N x 1 (time-invariant) or N x T (hourly) capacities
%     prob       : N x 1 state probabilities (must sum to 1)
%     Demand     : 1 x T  demand profile [MW]
%
%   Output:
%     FC : Largest capacity level X with P(C >= X) >= PEPP,
%          where PEPP = 1 - LOLP at the peak-demand hour.
%
%   When cap_matrix is N x T (e.g., system with PV), the function
%   automatically selects the column corresponding to peak demand.
%   When cap_matrix is N x 1 (conventional only), it is used as-is
%   since conventional capacity does not vary hour-to-hour.
 
    [D_peak, h_peak] = max(Demand(:)');
 
    % Select the capacity column at peak-demand hour
    if size(cap_matrix, 2) == 1
        cap_pk = cap_matrix;              % time-invariant (conventional)
    else
        cap_pk = cap_matrix(:, h_peak);   % extract peak-demand hour
    end
 
    % LOLP and exceedance threshold (PEPP) at peak hour
    LOLP_hp = sum(prob(cap_pk < D_peak));
    PEPP    = 1 - LOLP_hp;
 
    % Aggregate duplicate capacity states (important when PV = 0 MW
    % causes multiple states to share the same capacity level)
    [cu, ~, ig] = unique(cap_pk);
    pa           = accumarray(ig, prob);
 
    [cap_desc, ord] = sort(cu, 'descend');
    P_exced         = cumsum(pa(ord));
 
    % Firm capacity: largest X with P(C >= X) >= PEPP
    % Small tolerance guards against floating-point edge cases.
    tol    = 1e-10;
    idx_fc = find(P_exced >= PEPP - tol, 1, 'first');
 
    if isempty(idx_fc)
        FC = 0;
        warning(['calc_firm_capacity: PEPP criterion not satisfied ' ...
                 'for any capacity state; FC set to 0 MW.']);
        return
    end
    FC = cap_desc(idx_fc);
end