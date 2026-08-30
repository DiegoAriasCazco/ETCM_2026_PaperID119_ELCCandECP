clc; clear all;
%% ========================================================================
% PROCESAMIENTO MASIVO NSRDB -- PERFIL SOLAR PROMEDIO ECUADOR (13,017 pts)
% Fixes aplicados:
%   - HeaderLines corregido de 2 a 3 (estructura real del archivo)
%   - Columna GHI corregida de 17 a 6 (descarga GHI-only = 6 columnas)
%   - Enfoque streaming: acumula suma en lugar de matriz 8760x13017
%     (evita ~913 MB de RAM; solo necesita 2x8760 doubles = 140 KB)
%% ========================================================================
clc; clear; close all;

% --- CONFIGURACIÓN ---
folder_path  = '/Users/diegoarias/Documents/MATLAB/Confiabilidad/ELCC/Sistema_Ecuador/Perfil Solar';  % <-- ajusta esta ruta
GHI_REF_STC  = 1000;   % W/m² referencia estándar STC

% --- LOCALIZAR ARCHIVOS ---
file_list = dir(fullfile(folder_path, '*.csv'));
num_files = length(file_list);

if num_files == 0
    error('No se encontraron archivos .csv. Verifica la ruta: %s', folder_path);
end
fprintf('Archivos encontrados: %d\n', num_files);

%% ========================================================================
% LECTURA STREAMING (sin almacenar matriz completa en RAM)
% Acumula suma y conteo para calcular la media al final
%% ========================================================================
GHI_sum     = zeros(8760, 1);   % suma acumulada por hora
valid_count = 0;                 % archivos procesados correctamente
skip_count  = 0;                 % archivos con error o filas inesperadas

tic;
fprintf('Procesando archivos (reporte cada 500)...\n');

for i = 1:num_files

    full_path = fullfile(folder_path, file_list(i).name);

    try
        % CORRECCIÓN 1: HeaderLines = 3 (no 2)
        % Fila 1: metadatos fuente, Fila 2: unidades, Fila 3: Year/Month/...GHI
        data_num = readmatrix(full_path, 'NumHeaderLines', 3);

        % Verificar que tenga exactamente 8760 filas
        if size(data_num, 1) ~= 8760
            warning('Archivo %s tiene %d filas (esperado 8760). Omitido.', ...
                    file_list(i).name, size(data_num, 1));
            skip_count = skip_count + 1;
            continue
        end

        % CORRECCIÓN 2: GHI está en columna 6 (no 17)
        % Estructura: Year(1) Month(2) Day(3) Hour(4) Minute(5) GHI(6)
        ghi_col = data_num(:, 6);

        % Acumular suma
        GHI_sum = GHI_sum + ghi_col;
        valid_count = valid_count + 1;

    catch ME
        warning('Error leyendo %s: %s. Omitido.', ...
                file_list(i).name, ME.message);
        skip_count = skip_count + 1;
    end

    if rem(i, 500) == 0
        fprintf('  -> %d / %d archivos  |  válidos: %d  |  omitidos: %d\n', ...
                i, num_files, valid_count, skip_count);
    end
end

elapsed = toc;
fprintf('\nLectura completada en %.1f s (%.1f min)\n', elapsed, elapsed/60);
fprintf('Archivos válidos:  %d / %d\n', valid_count, num_files);
fprintf('Archivos omitidos: %d\n\n', skip_count);

%% ========================================================================
% CALCULAR PROMEDIO ESPACIAL Y FACTOR DE PLANTA
%% ========================================================================
GHI_promedio_8760 = GHI_sum / valid_count;      % W/m², media espacial

CF_8760 = GHI_promedio_8760 / GHI_REF_STC;     % normalizar a [0, 1]
CF_8760 = max(0, min(1, CF_8760));               % clamp por seguridad

fprintf('=== PERFIL SOLAR PROMEDIO ECUADOR ===\n');
fprintf('CF anual promedio  : %.4f  (%.1f%%)\n', ...
        mean(CF_8760), mean(CF_8760)*100);
fprintf('Pico GHI promedio  : %.1f W/m²\n', max(GHI_promedio_8760));
fprintf('Horas con sol (>0) : %d de 8760\n', sum(CF_8760 > 0));

%% ========================================================================
% VALIDACIÓN: PATRÓN ESTACIONAL MENSUAL
%% ========================================================================
days_pm = [31,28,31,30,31,30,31,31,30,31,30,31];
month_names = {'Jan','Feb','Mar','Apr','May','Jun', ...
               'Jul','Aug','Sep','Oct','Nov','Dec'};
CF_monthly_real = zeros(1,12);
idx = 0;
for m = 1:12
    n_hours = days_pm(m) * 24;
    CF_monthly_real(m) = mean(CF_8760(idx+1 : idx+n_hours));
    idx = idx + n_hours;
end

fprintf('\nCF promedio mensual (datos reales NSRDB):\n');
for m = 1:12
    fprintf('  %s : %.4f  (%.1f%%)\n', ...
            month_names{m}, CF_monthly_real(m), CF_monthly_real(m)*100);
end

%% ========================================================================
% FIGURAS DE VALIDACIÓN
%% ========================================================================
figure('Color','w','Units','inches','Position',[1 1 12 4]);

subplot(1,2,1)
plot(CF_8760, 'Color',[0.93 0.69 0.13],'LineWidth',0.8);
grid on; xlim([1 8760]);
xlabel('Hour of the Year'); ylabel('Capacity Factor [p.u.]');
title('Hourly Solar CF — Ecuador Spatial Average (NSRDB 2024)');
yline(mean(CF_8760),'r--','LineWidth',1.5,'DisplayName','Annual mean');
legend('CF','Annual mean','Location','northeast');

subplot(1,2,2)
bar(CF_monthly_real,'FaceColor',[0.93 0.69 0.13],'EdgeColor','k');
set(gca,'XTickLabel',month_names,'FontSize',9);
grid on;
xlabel('Month'); ylabel('Average CF [p.u.]');
title('Monthly Average CF — Ecuador');
yline(mean(CF_monthly_real),'r--','LineWidth',1.5);

%% ========================================================================
% GUARDAR: formato compatible con el script principal de simulación
%% ========================================================================
save('CF_Ecuador_NSRDB_8760.mat', 'CF_8760', 'GHI_promedio_8760', ...
     'CF_monthly_real', 'valid_count');

fprintf('\nGuardado: CF_Ecuador_NSRDB_8760.mat\n');
fprintf('Variable principal: CF_8760  (8760x1, compatible con script principal)\n');
fprintf('\nPara usar en el script de simulación, reemplaza:\n');
fprintf('  CF_8760 = ...  (perfil sintético)\n');
fprintf('por:\n');
fprintf('  load(''CF_Ecuador_NSRDB_8760.mat'', ''CF_8760'');\n');