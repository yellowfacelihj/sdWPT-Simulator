clear all;clc;
w = 2*pi*1000000;%1MHz
u = pi*4e-7;%permeabilidade magnética
P = 20;%potência ativa em W
Qmax = 1.43;%carga máxima em Ah
step = 0.2/3600;%passo de integração (h)
eff = 0.95;%eficiência de conversão

%Potência do dispositivo consumidor
sPower = 0.7;

%tensão mínima operacional
minVTO = 3;

%referência para a inclinação média das curvas de carregamento em função de tempo
coef_ref = [1/2.5;1/3.5;1/4.8;1/8.8];

%carregando os dados de acoplamento do sistema
%data(instância).M(índice relativo à distância).obj -> matriz de acoplamento
load('tunningMagMIMOTrackingData.mat');

%resistência equivalente em função da carga
rlLookupTable = LookupTable('magMIMOLinearBattery_data.txt',false);
%tensão em função da carga
vbLookupTable = LookupTable('Li_Ion_Battery_LIR18650.txt',false);

%hold on;
E = [];%dados de log
minErr = inf;%erro mínimo conhecido até o momento

for d=1:length(data)%instância (design da bobina receptora)
	%para o controle das instâncias a serem utilizadas
	if((data(d).N_rx>1)&&(data(d).A_rx<0.075)&&(data(d).B_rx<0.075))
		disp(['Iniciando nova instância: R1_rx=',num2str(data(d).R1_rx),...
			' N_rx=',num2str(data(d).N_rx),...
			' A_rx=',num2str(data(d).A_rx),...
			' B_rx=',num2str(data(d).B_rx)]);
		for Rr = [2,5,10,20,25,30]%resistência do ressonador no receptor
		%resistência de cada ressonador transmissor
			for Rt = [0.01,0.025,0.05,0.075,0.1,0.25,0.5]
				err = [0,0,0,0];%erro (para cada distância)
				for i=1:4%para cada distância
					%calculando a matriz de impedância
					Z = -(1i)*w*u*data(d).M(i).obj + diag([Rt*ones(6,1);Rr]);
					%vetor de qualidade de canal*Rl
					m_Rl = (1i)*w*u*data(d).M(i).obj(1:6,7);
					%lista com a progressão da carga
					Q = [];
					%lista com a progressão da resistência equivalente do circuito da bateria
					RL = [];
					%lista com a progressão da corrente no anel receptor
					IL = [];
					%carga atual (inicialmente morta)
					q=0;
					%tempo máximo de simulação em horas
					ttl=20;
					%tempo desde o início dessa simulação
					t = 0.4/3600;
					
					fase=0;
					while true
						%obtem a resistência equivalente do circuito da bateria
						%(dado o estado atual)
						Rl = getYFromX(rlLookupTable,q/Qmax);
						RL = [RL;Rl];
						%obtém a tensão da bateria dado o estado atual
						Vb = getYFromX(vbLookupTable,q/Qmax);
						%vetor de qualidade de canal
						m  = m_Rl/(Rl+Rr);
						%fazendo o tempo passar
						t = t-step;
						if fase<6
							I = (Z+diag([zeros(6,1);Rl]))\[zeros(fase,1);1;zeros(6-fase,1)];
							Il = I(7);
							if t<=0
								fase = fase+1;
								if fase==6
									t = 30/3600;
								else
									t = 0.4/3600;
								end
							end
						else
							%calculando a base do vetor de correntes do dispositivo transmissor
							beta = m./sum(abs(m).^2);
							%calculando a corrente do receptor caso seja aplicada beta
							bl = m.'*beta;
							%normalizando a corrente de transmissão baseada em m mas de forma a
							%não superar a potência P
							It = beta*...
								(sqrt(P/real([beta;bl]'*(Z+diag([zeros(6,1);Rl]))*[beta;bl])));
							%aplicando a nova corrente transmissora e obtendo a corrente de
							%recebimento
							Il = m.'*It;
							if t<=0
								fase = 0;
								t = 0.4/3600;
							end
						end
						IL = [IL;Il];
						%corrente de descarga
						if Vb>=minVTO
							Id = sPower/Vb;
						else
							Id = 0;
						end
						%incrementando a carga
						q = q+eff*(abs(Il)-Id)*step;
						%limitando a carga a 100%
						if q>=Qmax
							Q = [Q;Qmax];
							break;
						else
							Q = [Q;q];
						end
						%controle de tempo
						ttl = ttl-step;
						if ttl<0
							break;
						end
						t = t-step;
					end
					%se o loop foi rompido pelo ttl<0, o teste foi muito desastroso para ser
					%considerado
					if ttl<0
						err(i) = inf;
					else
						%calculando o erro em relação ao referencial adotado
						err_parc = (Q.')/Qmax-coef_ref(i)...
							*linspace(0,step*(length(Q)-1),length(Q));
						err(i) = mean(err_parc.^2);
					end
					
					%plot(cFactor(i)*linspace(0,step*(length(Q)-1),length(Q)),100*Q/Qmax);
					%plot(linspace(0,step*(length(RL)-1),length(RL)),RL);
					%plot(linspace(0,step*(length(Q)-1),length(Q)),100*Q/Qmax);
					%plot(linspace(0,1/coef_ref(i),2),100*coef_ref(i)*linspace(0,1/coef_ref(i),2),'g');
				end
				%log
				e.Rt = Rt;
				e.Rr = Rr;
				e.err = sum(err);
				e.d = d;
				E = [E,e];
				%verificando o menor valor de erro
				if e.err<minErr
					minErr = e.err;
				end
				disp(['MIN ERR: ', num2str(minErr)]);
			end
		end
	end
end

