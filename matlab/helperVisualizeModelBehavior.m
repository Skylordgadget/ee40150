function helperVisualizeModelBehavior(normalData, abnormalData, decodedNorm, decodedAbNorm)
%HELPERVISUALIZEMODELBEHAVIOR Visualize model behavior on sample validation data

figure("Color", "W")
tiledlayout("flow")

nexttile()
hold on
colororder('default')
yyaxis left
plot(normalData')
plot(decodedNorm',":","LineWidth",1.5)
hold off
title("Normal Input")
grid on
ylabel("Feature Value")
yyaxis right
stem(abs(normalData' - decodedNorm'))
disp('new mse')
disp(mean(abs(normalData' - decodedNorm').^2))
ylim([0 2])
ylabel("Error")
legend(["Input", "Decoded","Error"],"Location","southwest")

nexttile()
hold on
yyaxis left
plot(abnormalData)
plot(decodedAbNorm',":","LineWidth",1.5)
hold off
title("Abnormal Input")
grid on
ylabel("Feature Value")
yyaxis right
stem(abs(abnormalData' - decodedAbNorm'))
disp('worn mse')
disp(mean(abs(abnormalData' - decodedAbNorm').^2))
ylim([0 2])
ylabel("Error")
legend(["Input", "Decoded","Error"],"Location","southwest")

end