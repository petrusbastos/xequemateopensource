#include <Trade\Trade.mqh>
#include <Timer.mqh>
#include <Controls\Dialog.mqh>
#include <Controls\Label.mqh>
#include <Controls\Button.mqh>

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
//--- indents and gaps
#define INDENT_LEFT                         (11)      // indent from left (with allowance for border width)
#define INDENT_TOP                          (11)      // indent from top (with allowance for border width)
#define CONTROLS_GAP_X                      (5)       // gap by X coordinate
//--- for buttons
#define BUTTON_WIDTH                        (100)     // size by X coordinate
#define BUTTON_HEIGHT                       (20)      // size by Y coordinate

CTrade trade;
CNewBar NewBar;
CAppDialog AppWindow;

CLabel              m_label1;                       // the button object
CLabel              m_label2;                       // the button object
CLabel              m_label3;                       // the button object
CLabel              m_label4;                       // the button object
CLabel              m_label5;                       // the button object
CLabel              m_label6;                       // the button object
CLabel              m_label7;                       // the button object

#property script_show_inputs 
//--- SIM ou NÃO
enum SIM_NAO
  { 
   SIM=1,     // SIM
   NAO=0,     // NÃO
  }; 

// Configurações Base
input string                  configs_base = "Configurações Base";//Configurações Base
input string                  nome_ea = "XM - Open Source"; //Nome do EA
input ENUM_TIMEFRAMES         tempo_grafico = PERIOD_M15; //Tempo Gráfico
input ulong                   magicNum = 123456;//Magic Number
input SIM_NAO                 exibir_logs_grafico = SIM; //Exibir Logs no gráfico?
//cor do log
// tipo da janela móvel de resultados
input ENUM_ORDER_TYPE_FILLING preenchimento = ORDER_FILLING_RETURN;//Tipo do preenchimento de ordens à mercado
input ENUM_ORDER_TYPE_FILLING preenchimento_ordens_pendentes = ORDER_FILLING_RETURN;//Tipo do preenchimento de ordens pendentes
input ENUM_ORDER_TYPE_TIME    validade_ordens_pendentes = ORDER_TIME_DAY;//Tipo da validade das ordens pendentes

// Simulador de Custos Operacionais
input string                  custos_operacionais = "*** Custos Operacionais ***";//*** Custos Operacionais ***
input double                  custo_operacional_fixo_por_contrato = 0.48;//Custo operacional fixo por contrato
//custo operacional fixo por ordem
//exportação de dados do BT
//id do setup para hedge analyzer

// Parâmetros da Estratégia
input string                  parametros_estrategia = "*** Parâmetros da Estratégia ***";//*** Parâmetros da Estratégia ***
input int                     ma_periodo = 15; //Período da Média Móvel
input int                     distancia_media = 800; //Distância da Média em pontos
input int                     distancia_ordem_limit = 50; //Distância da ordem Limit
input int                     tempo_validade_ordem_limit = 900; //Tempo validade ordem limit [segundos] (0=Off)
input int                     numero_contratos = 1; //Número de contratos
input SIM_NAO                 filtro_gap = NAO; //[FILTRO GAP] Não operar dias com GAP maior que

// Parâmetros de Saída
input string                  parametros_saida = "*** Parâmetros de Saída ***";//*** Parâmetros de Saída ***
input SIM_NAO                 fechar_operacao_tensao = SIM; //Fechar Operação pela Tensão?
input double                  percentual_tensao_saida = 0; //% Tensão p/ saída

// Stops iniciais
input string                  stops_iniciais = "*** Stops Iniciais ***";//*** Stops Iniciais ***
input int                     stop_loss = 1200; //Stop Loss em pontos (SL)
input int                     stop_gain = 5000; //Stop Gain em pontos (TP)

// Janela de Operações
input string                  janela_operacoes = "*** Janela de Operações ***"; //*** Janela de Operações ***
input SIM_NAO                 marcar_horarios_linhas_verticais = SIM; //Marcar horários c/ linhas verticais no gráfico?
//dias da semana permitidos
//operar de segunda-feira
//operar de terça-feira
//operar de quarta-feira
//operar de quinta-feira
//operar de sexta-feira
//operar de sábado
//operar de domingo

// Período Diário
input string                  periodo_diario = "Período Diário"; //Período Diário
input string                  horario_inicial_abrir_posicoes = "09:30"; //Horário inicial permitido p/ abrir posições
input string                  horario_final_abrir_posicoes = "12:00"; //Horário final permitido p/ abrir posições

// Fechamento Diário
input string                  fechamento_diario = "Fechamento Diário"; //Fechamento Diário
input SIM_NAO                 fechar_posicoes_final_dia = SIM; //Fechar posições no final de cada dia?
input string                  horario_fechar_todas_posicoes = "13:00"; //Horário para fechar todas as posições em aberto

// Alertas e Notificações
input string                  alertas_notificacoes = "Alertas e Notificações"; //Alertas e Notificações
input SIM_NAO                 exibir_alerta_mt5_novas_posicoes = NAO; // Exibir um alerta no MT5 ao abrir novas posições?
input SIM_NAO                 enviar_notificacao_smartphone_primeiro_tick = SIM; // Notificação no Smartphone no primeiro tick do dia? 
input SIM_NAO                 enviar_notificacao_smartphone_novas_posicoes = SIM;// Notificação no Smartphone ao abrir novas posições? 
input SIM_NAO                 enviar_notificacao_smartphone_fechar_posicoes = SIM;// Notificação no Smartphone ao fechar posições? 
input SIM_NAO                 enviar_notificacao_smartphone_perda_conexao_corretora = SIM;// Notificação no Smartphone ao perder conexão com a corretora? 

input int                     ma_desloc = 0;//Deslocamento da Média
input ENUM_MA_METHOD          ma_metodo = MODE_SMA;//Método Média Móvel
input ENUM_APPLIED_PRICE      ma_preco = PRICE_CLOSE;//Preço para Média

input ulong                   desvPts = 50;//Desvio em Pontos

double                        smaArray[];
int                           smaHandle;

bool                          posAberta;

MqlTick                       ultimoTick;
MqlRates                      rates[];

int                           quantidade_rates;

MqlDateTime Time;

datetime                      inicio_dia;
datetime                      inicio_abertura;
datetime                      final_abertura;
datetime                      fechamento_posicoes;

int                           barra_inferior;
int                           barra_superior;

//+---------------------------------------------------------------------------------+
//| Normalização do preço para não ficar com valores quebrados direfentes de 0 ou 5 |
//+---------------------------------------------------------------------------------+
double normalizePrice(double price){
   double tickSize=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   return(MathRound(price/tickSize)*tickSize);
}

// Definição de variáveis para armazenar os ganhos do robô
const string GANHO_DIA = "XequeMate_OpenSource_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +_Symbol+"_GANHO_DIA";
const string GANHO_SEM = "XequeMate_OpenSource_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +_Symbol+"_GANHO_SEM";
const string GANHO_MES = "XequeMate_OpenSource_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +_Symbol+"_GANHO_MES";
const string GANHO_TOTAL = "XequeMate_OpenSource_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +_Symbol+"_GANHO_TOTAL";
string operacoes_dia = "XequeMate_OpenSource_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) +_Symbol+"_OPERACOES_DIA_"+IntegerToString(TimeCurrent());

//+------------------------------------------------------------------+
// Função para determinar o tipo da conta (DEMO, CONTEST ou REAL)    |
//+------------------------------------------------------------------+
string GetTipoConta(){
   ENUM_ACCOUNT_TRADE_MODE tradeMode=(ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE); 
   //--- Descobre o tipo de conta 
   string retorno = "";
   switch(tradeMode) 
     { 
      case(ACCOUNT_TRADE_MODE_DEMO): 
         retorno = "DEMO"; 
         break; 
      case(ACCOUNT_TRADE_MODE_CONTEST): 
         retorno = "CONTEST"; 
         break; 
      default:retorno = "REAL"; 
     }
   return retorno;       
}

//+------------------------------------------------------------------+
//| Create the "label1"                                              |
//+------------------------------------------------------------------+
bool CreateLabel1(void)
  {
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=INDENT_TOP;         // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label1.Create(0,"Label1",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label1.Text("XM["+GetTipoConta()+"]x"+IntegerToString(numero_contratos)))
      return(false);
   // Adiciona o label ao quadro resumo      
   if(!AppWindow.Add(m_label1))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label2"                                              |
//+------------------------------------------------------------------+
bool CreateLabel2(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*2)+6;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label2.Create(0,"Label2",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label2.Text("Ativo: " + _Symbol))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label2))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label3"                                              |
//+------------------------------------------------------------------+
bool CreateLabel3(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*3)+12;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label3.Create(0,"Label3",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label3.Text("LUCROS COM O ROBÔ"))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label3))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label4"                                              |
//+------------------------------------------------------------------+
bool CreateLabel4(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*4)+18;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label4.Create(0,"Label4",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label4.Text("Total: R$..."))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label4))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label5"                                              |
//+------------------------------------------------------------------+
bool CreateLabel5(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*5)+24;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label5.Create(0,"Label5",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label5.Text("No mês: R$..."))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label5))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label6"                                              |
//+------------------------------------------------------------------+
bool CreateLabel6(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*6)+30;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label6.Create(0,"Label6",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label6.Text("Na semana: R$..."))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label6))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create the "label7"                                              |
//+------------------------------------------------------------------+
bool CreateLabel7(void){
   // Coordenadas
   int x1=INDENT_LEFT;        // x1            = 11  pixels
   int y1=(INDENT_TOP*7)+36;   // y1            = 11  pixels
   int x2=x1+BUTTON_WIDTH;    // x2 = 11 + 100 = 111 pixels
   int y2=y1+BUTTON_HEIGHT;   // y2 = 11 + 20  = 32  pixels
   // Cria o label
   if(!m_label7.Create(0,"Label7",0,x1,y1,x2,y2))
      return(false);
   // Seta o texto do label
   if(!m_label7.Text("No dia: R$..."))
      return(false);
   // Adiciona o label ao quadro resumo   
   if(!AppWindow.Add(m_label7))
      return(false);
   //  Informa que a rotina foi executada com sucesso
   return(true);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Cria o quadro resumo                                             |
//+------------------------------------------------------------------+
bool CriarQuadroResumo(){
   // Cria o quadro resumo
   if(!AppWindow.Create(0,"XM - Quadro Resumo",0,10,20,200,200))
      return(INIT_FAILED);
   // Cria o label1
   if(!CreateLabel1())
      return(false);
   // Cria o label2
   if(!CreateLabel2())
      return(false);
   // Cria o label3
   if(!CreateLabel3())
      return(false);      
   // Cria o label4
   if(!CreateLabel4())
      return(false);      
   // Cria o label5
   if(!CreateLabel5())
      return(false);      
   // Cria o label6
   if(!CreateLabel6())
      return(false);     
   // Cria o label7
   if(!CreateLabel7())
      return(false);      
   // Executa o quadro resumo
   AppWindow.Run();
   return true;
}
//+------------------------------------------------------------------+

// Função executa quando o robô inicializa
int OnInit(){

   smaHandle = iMA(_Symbol, _Period, ma_periodo, ma_desloc, ma_metodo, ma_preco);
   if(smaHandle==INVALID_HANDLE)
      {
         Print("Erro ao criar média móvel - erro", GetLastError());
         return(INIT_FAILED);
      }
   ArraySetAsSeries(smaArray, true);
   ArraySetAsSeries(rates, true);
   
   quantidade_rates = ArraySize(rates);
   
   // Seta o tipo do preenchimento de ordens à mercado
   trade.SetTypeFilling(preenchimento);
   // Seta o desvio em pontos
   trade.SetDeviationInPoints(desvPts);
   // Seta o magic number do EA
   trade.SetExpertMagicNumber(magicNum);
   
   // Prepara as propriedades do gráfico
   // Removendo o grid
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   // Seta como gráfico de candles
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES); 
   // Seta o tempo gráfico
   ChartSetSymbolPeriod(0, _Symbol, tempo_grafico);
   // Seta as cores da barra de alta
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,clrDodgerBlue);
   ChartSetInteger(0,CHART_COLOR_CHART_UP,clrDodgerBlue);   
   // Seta as cores da barra de baixa
   ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,clrBlack);
   ChartSetInteger(0,CHART_COLOR_CHART_DOWN,clrSteelBlue);
   //Seta a cor da barra de indecisão
   ChartSetInteger(0,CHART_COLOR_CHART_LINE,clrDodgerBlue);
   // Seta a propriedade de exibir o último valor e a sua cor
   // TODO ver aqui porque não está ficando verde...   
   ChartSetInteger(0,CHART_SHOW_LAST_LINE,true);   
   ChartSetInteger(0,CHART_COLOR_LAST,clrRed);   
   // Seta a propriedade de exibir o valor bid e a sua cor
   ChartSetInteger(0,CHART_SHOW_BID_LINE,true);      
   ChartSetInteger(0,CHART_COLOR_BID,clrGray);   
   // Seta a propriedade de exibir o valor ask e a sua cor
   ChartSetInteger(0,CHART_SHOW_ASK_LINE,true);
   ChartSetInteger(0,CHART_COLOR_ASK,clrGray);
   
   // Adiciona as variáveis que armazenam os ganhos inicialmente
   if (!GlobalVariableCheck(GANHO_DIA)){
      GlobalVariableSet(GANHO_DIA,0);
   }
   if (!GlobalVariableCheck(GANHO_SEM)){
      GlobalVariableSet(GANHO_SEM,0);
   }
   if (!GlobalVariableCheck(GANHO_MES)){
      GlobalVariableSet(GANHO_MES,0);
   }
   if (!GlobalVariableCheck(GANHO_TOTAL)){
      GlobalVariableSet(GANHO_TOTAL,0);
   }
   if (!GlobalVariableCheck(operacoes_dia)){
      GlobalVariableSet(operacoes_dia,0);
      Print(operacoes_dia);
   }
   
   // Cria o quadro resumo
   CriarQuadroResumo();
   
   // Retorna operação com sucesso
   return(INIT_SUCCEEDED);

}

//+------------------------------------------------------------------+
//| Função de evento do gráfico do Expert                            |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,         // ID do evento  
                  const long& lparam,   // parâmetro do evento do tipo long
                  const double& dparam, // parâmetro do evento do tipo double
                  const string& sparam) // parâmetro do evento do tipo string
  {
   AppWindow.ChartEvent(id,lparam,dparam,sparam);
  }

void OnDeinit(const int reason)
  {
//--- destrói o diálogo
   AppWindow.Destroy(reason);
  }

// Função que verifica se o dia já foi encerrado
bool roboFinalizadoNoDia(){

   if (GlobalVariableCheck("position_identifier") && PositionsTotal() == 0){
      return true;
   } else {
      return false;
   }

}

// Função que formata valores double em reais
string formatarReais(double number, int precision=2, string pcomma=".", string ppoint=",")
{
   string snum   = DoubleToString(number,precision);
   int    decp   = StringFind(snum,".",0);
   string sright = StringSubstr(snum,decp+1,precision);
   string sleft  = StringSubstr(snum,0,decp);
   string formated = "";
   string comma    = "";
   
      while (StringLen(sleft)>3)
      {
         int    length = StringLen(sleft);
         string part   = StringSubstr(sleft,length-3,0);
              formated = part+comma+formated;
              comma    = pcomma;
              sleft    = StringSubstr(sleft,0,length-3);
      }
      if (sleft=="-")  comma=""; // this line missing previously
      if (sleft!="")   formated = sleft+comma+formated;
      if (precision>0) formated = formated+ppoint+sright;
   return(formated);
}

// Função executada a cada novo tick
void OnTick(){
              
   if(!SymbolInfoTick(Symbol(),ultimoTick)){
      Alert("Erro ao obter informações de Preços: ", GetLastError());
      return;
   }
      
   if(CopyRates(_Symbol, _Period, 0, 3, rates)<0){
      Alert("Erro ao obter as informações de MqlRates: ", GetLastError());
      return;
   }
   
   if(CopyBuffer(smaHandle, 0, 0, 3, smaArray)<0){
      Alert("Erro ao copiar dados da média móvel: ", GetLastError());
      return;
   }
  
   // Verifica se já foi realizada alguma operação no dia
   if (!roboFinalizadoNoDia()){
   
      // Verifica a configuração de marcação dos horários com linhas verticais
      TimeToStruct (rates[0].time, Time);      
      if (marcar_horarios_linhas_verticais == SIM && Time.hour == 9 && Time.min == 0){
         
         // Recupera a data atual para utilizar nas variáveis das linhas de cada dia         
         string CurrDate = TimeToString(TimeCurrent(), TIME_DATE);
   
         // Plota a barra inicial do dia
         inicio_dia = StringToTime(CurrDate + " 09:00:00");
         ObjectCreate(0,"VerticalInicio"+CurrDate,OBJ_VLINE,0,inicio_dia,0); 
         ObjectSetInteger(0,"VerticalInicio"+CurrDate,OBJPROP_COLOR,clrSteelBlue);         
         ObjectSetInteger(0,"VerticalInicio"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra inicial de abertura de posições
         inicio_abertura = StringToTime(CurrDate + " " + horario_inicial_abrir_posicoes + ":00");
         ObjectCreate(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJ_VLINE,0,inicio_abertura,0); 
         ObjectSetInteger(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJPROP_COLOR,clrMediumSpringGreen);         
         ObjectSetInteger(0,"VerticalInicioAbrirPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra final de abertura de posições
         final_abertura = StringToTime(CurrDate + " " + horario_final_abrir_posicoes + ":00");
         ObjectCreate(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJ_VLINE,0,final_abertura,0); 
         ObjectSetInteger(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJPROP_COLOR,clrSteelBlue);         
         ObjectSetInteger(0,"VerticalFinalAbrirPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
         // Plota a barra final de fechamento de todas as posições
         fechamento_posicoes = StringToTime(CurrDate + " " + horario_fechar_todas_posicoes + ":00");
         ObjectCreate(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJ_VLINE,0,fechamento_posicoes,0); 
         ObjectSetInteger(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJPROP_COLOR,clrTomato);
         ObjectSetInteger(0,"VerticalFinalFecharPosicoes"+CurrDate,OBJPROP_STYLE,STYLE_DOT);
         
      }
      
      // Atualizar o TP da posição de acordo com a média a cada novo candle
      if (PositionsTotal() > 0){      
         ObjectDelete(0, "HorizontalTop");
         ObjectDelete(0, "HorizontalBottom");
      }
      
      // Verifica se está no horário de funcionamento do robô   
      if ((TimeCurrent() > inicio_abertura || TimeCurrent() == inicio_abertura) && TimeCurrent() < final_abertura){
         
         // Verifica se é um novo candle         
         bool newBar = NewBar.CheckNewBar(_Symbol,_Period);
         int barShift = 1;
         
         MqlTradeRequest request;
         MqlTradeResult  result;
         
         // Se for um novo candle, atualiza as barras superior e inferior
         if (newBar == true){
            
            // Define os valores das barras superior e inferior
            barra_superior = smaArray[0] + distancia_media;
            barra_inferior = smaArray[0] - distancia_media;
            
            // Adiciona as barras de alerta de negociação
            if (PositionsTotal() == 0 && GlobalVariableGet(operacoes_dia) == 0){
            
               // Gerencia as barras de distância à média
               ObjectDelete(0, "HorizontalTop");
               ObjectDelete(0, "HorizontalBottom");
               
               // Adiciona a barra superior
               //ObjectDelete(0, "HorizontalTop");
               ObjectCreate(0,"HorizontalTop",OBJ_HLINE,0,rates[0].time,barra_superior);
               ObjectSetInteger(0,"HorizontalTop",OBJPROP_COLOR,clrRed);        
                           
               // Adiciona a barra inferior
               //ObjectDelete(0, "HorizontalBottom");
               ObjectCreate(0,"HorizontalBottom",OBJ_HLINE,0,rates[0].time,barra_inferior);
               ObjectSetInteger(0,"HorizontalBottom",OBJPROP_COLOR,clrBlue);
            } else {
               // Seta a informação de que tem operação sendo realizada
               GlobalVariableSet(operacoes_dia, PositionsTotal());
            }
            
            // Atualizar o TP da ordem de acordo com a média a cada novo candle
            if (OrdersTotal() > 0){
               ZeroMemory(request);
               ZeroMemory(result);
               request.action=TRADE_ACTION_MODIFY; // tipo de operação de negociação
               request.order = OrderGetTicket(0); // bilhete da ordem
               //request.symbol =OrderGetString(ORDER_SYMBOL); // símbolo         
               int old_tp = OrderGetDouble(ORDER_TP);
               request.tp = normalizePrice(smaArray[0]);                
               request.sl = OrderGetDouble(ORDER_SL);
               request.price =OrderGetDouble(ORDER_PRICE_OPEN);  // preço de abertura normalizado
               if (old_tp != normalizePrice(smaArray[0])){
                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError()); // se não foi possível enviar o pedido, exibir o código de erro          
                  //--- zerado dos valores do pedido e o seu resultado
               }   
               ZeroMemory(request);
               ZeroMemory(result);   
            }
            
            // Atualizar o TP da posição de acordo com a média a cada novo candle
            if (PositionsTotal() > 0){      
            
               ZeroMemory(request);
               ZeroMemory(result);
               //--- definição dos parâmetros de operação
               request.action  =TRADE_ACTION_SLTP; // tipo de operação de negociação
               request.position=PositionGetTicket(0);   // bilhete da posição
               // TODO ajeitar aqui o nome da variável
               GlobalVariableSet("position_identifier", PositionGetInteger(POSITION_IDENTIFIER));
               request.symbol=PositionGetString(POSITION_SYMBOL);     // símbolo 
               int old_tp = PositionGetDouble(POSITION_TP);
               
               //Comment("Lucro: " + PositionGetDouble(POSITION_PROFIT));
               
               //ObjectCreate(0,"ObjName", OBJ_LABEL, 0, rates[0].time, PositionGetDouble(POSITION_PRICE_CURRENT)); 
               string value1=DoubleToString(PositionGetDouble(POSITION_PROFIT), 2);
                          
               //ObjectCreate(0,"TextProfit",OBJ_LABEL,0,rates[0].time,smaArray[0]);
               //ObjectSetString(0,"TextProfit",OBJPROP_TEXT,"R$"+value1);        
               //ObjectSetInteger(0,"TextProfit",OBJPROP_XDISTANCE,20);        
               //ObjectSetInteger(0,"TextProfit",OBJPROP_YDISTANCE,20);        
               
               request.sl      =PositionGetDouble(POSITION_SL);                // Stop Loss da posição
               request.tp      =normalizePrice(smaArray[0]);                // Take Profit da posição
               request.magic=PositionGetInteger(POSITION_MAGIC);         // MagicNumber da posição         
               if (old_tp != normalizePrice(smaArray[0])){
                  if(!OrderSend(request,result))
                     PrintFormat("OrderSend error %d",GetLastError());  // se não for possível enviar o pedido, exibir o código de erro
               }
               ZeroMemory(request);
               ZeroMemory(result);
            }
            
         }
        
         // TODO Verificar se já tem aguma posição aberta
         //posAberta = false;
         //for(int i = PositionsTotal()-1; i>=0; i--){
         //   string symbol = PositionGetSymbol(i);
         //   ulong magic = PositionGetInteger(POSITION_MAGIC);
         //   if(symbol == _Symbol && magic==magicNum){  
         //      posAberta = true;
         //      break;
         //   }
         //}
         
         // Se estiver nas condições de compra ou de venda e não tiver nenhuma ordem ou posição em aberto, pendura a ordem
         int takeProfit = 0;
         if ((ultimoTick.last ==  barra_superior || ultimoTick.last > barra_superior) && OrdersTotal() == 0 && PositionsTotal() == 0){  
            takeProfit = (ultimoTick.last + distancia_ordem_limit - normalizePrice(smaArray[0])) < stop_gain ? normalizePrice(smaArray[0]) : ultimoTick.last - stop_gain;
            if (trade.SellLimit(numero_contratos, normalizePrice(ultimoTick.last + distancia_ordem_limit), _Symbol, normalizePrice(ultimoTick.last + distancia_ordem_limit + stop_loss), takeProfit, ORDER_TIME_DAY, tempo_validade_ordem_limit, "Ordem de Venda do XM")){
               Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
            } else {
               Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
            }
         } else if ((ultimoTick.last ==  barra_inferior || ultimoTick.last < barra_inferior) && OrdersTotal() == 0 && PositionsTotal() == 0){
            takeProfit = (normalizePrice(smaArray[0]) - ultimoTick.last + distancia_ordem_limit) < stop_gain ? normalizePrice(smaArray[0]) : ultimoTick.last + stop_gain;
            if (trade.BuyLimit(numero_contratos, normalizePrice(ultimoTick.last - distancia_ordem_limit), _Symbol, normalizePrice(ultimoTick.last - distancia_ordem_limit - stop_loss), takeProfit, ORDER_TIME_DAY, tempo_validade_ordem_limit, "Ordem de Compra do XM")){
               Print("Ordem de Venda - sem falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
            } else {
               Print("Ordem de Venda - com falha. ResultRetcode: ", trade.ResultRetcode(), ", RetcodeDescription: ", trade.ResultRetcodeDescription());
            }
         }     
            
      }
   
   } else {
      
      // Ao final do trade, coloca o valor de ganho ou perda perto da seta
      color BuyColor =clrBlue; 
      color SellColor=clrRed; 
      //--- história do negócio pedido 
      HistorySelect(0,TimeCurrent()); 
      //--- cria objetos 
      //string   name; 
      uint     total=HistoryDealsTotal(); 
      ulong    ticket=0; 
      double   price; 
      double   profit; 
      datetime time; 
      string   symbol; 
      long     type; 
      long     entry; 
      //--- para todos os negócios 
      for(uint i=0;i<total;i++){          
         if((ticket=HistoryDealGetTicket(i))>0){ 
            price =HistoryDealGetDouble(ticket,DEAL_PRICE); 
            time  =(datetime)HistoryDealGetInteger(ticket,DEAL_TIME); 
            symbol=HistoryDealGetString(ticket,DEAL_SYMBOL); 
            type  =HistoryDealGetInteger(ticket,DEAL_TYPE); 
            entry =HistoryDealGetInteger(ticket,DEAL_ENTRY); 
            profit=HistoryDealGetDouble(ticket,DEAL_PROFIT); 
            //--- apenas para o símbolo atual 
            if(price && time && symbol==Symbol() && profit != 0){ 
               //--- cria o preço do objeto 
               //name="TradeHistory_Deal_"+string(ticket); 
               //if(entry) ObjectCreate(0,name,OBJ_ARROW_RIGHT_PRICE,0,time,price,0,0); 
               //else      ObjectCreate(0,name,OBJ_ARROW_LEFT_PRICE,0,time,price,0,0); 
               //--- definir propriedades do objeto 
               //ObjectSetInteger(0,name,OBJPROP_SELECTABLE,0); 
               //ObjectSetInteger(0,name,OBJPROP_BACK,0); 
               //ObjectSetInteger(0,name,OBJPROP_COLOR,type?BuyColor:SellColor); 
               //if(profit!=0) {
               string text_name="EA_ResultadoTrade_" + IntegerToString(ticket); 
               ObjectCreate(0,text_name,OBJ_TEXT,0,time,price); 
               ObjectSetInteger(0,text_name,OBJPROP_COLOR,profit<0?clrRed:clrBlue); 
               ObjectSetString(0,text_name,OBJPROP_TEXT,profit<0?"   -R$":"   R$" + formatarReais(profit)); 
               ObjectSetString(0,text_name,OBJPROP_FONT,"Trebuchet MS"); 
               ObjectSetInteger(0,text_name,OBJPROP_FONTSIZE,10); 
               ObjectSetInteger(0,text_name,OBJPROP_ANCHOR,ANCHOR_LEFT); 
               ObjectSetInteger(0,text_name,OBJPROP_SELECTABLE,false);
               //}
            } 
         } 
      } 
      //--- aplicar no gráfico 
      ChartRedraw(); 
      
   }

}