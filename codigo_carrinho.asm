INCLUDE <p16f628a.inc>
__CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

; ====================
; VARIÁVEIS
; ====================
ESTADO_SENSORES    EQU 0x70    ; Estado dos sensores (PORTB)
CONTADOR_CURVAS    EQU 0x72    ; Quantidade de curvas realizadas
CONTADOR_DELAY     EQU 0x73    ; Contador para delays
DIRECAO           EQU 0x74    ; Direção da 1ª curva (0=direita, 1=esquerda)
SEGUNDA_FASE      EQU 0x75    ; Flag para indicar segunda fase (0=inicial, 1=após 3ª curva)
CONFIG_CURVAS     EQU 0x76    ; Configuração das curvas 4 e 5 (RA4,RA5)
CONTADOR_1S       EQU 0x77    ; Contador para delay de 1s
TEMP             EQU 0x78    ; Variável temporária

; ====================
; VETORES
; ====================
ORG 0x00
GOTO INICIO
ORG 0x04
RETFIE

; ====================
; INICIALIZAÇÃO
; ====================
INICIO:
    CLRF CONTADOR_CURVAS
    CLRF SEGUNDA_FASE
    
    ; Configuração do comparador analógico
    BANKSEL CMCON
    MOVLW 0x07
    MOVWF CMCON
    
    ; Configuração dos TRIS
    BANKSEL TRISA
    MOVLW B'00111100'     ; RA2-RA5 como entrada (chaves)
    MOVWF TRISA
    MOVLW B'00000111'     ; RB0-RB2 como entrada (sensores)
    MOVWF TRISB
    
    ; Estado inicial do carro (anda reto)
    BANKSEL PORTB
    MOVLW B'00101000'     ; RB3 e RB5 ativos
    MOVWF PORTB
    MOVLW B'00000011'     ; RA0 e RA1 ativos
    MOVWF PORTA
    
    ; Lê chaves UMA VEZ para determinar direção da 1ª curva
    CALL LER_CHAVES_E_DECIDE_DIRECAO

; ====================
; LOOP PRINCIPAL
; ====================
LOOP_PRINCIPAL:
    CALL LER_SENSORES
    
    ; Verifica se já fez 3 curvas na PRIMEIRA FASE
    MOVLW 0x03
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    CALL PROCESSAR_TERCEIRA_CURVA
    
    ; Verifica padrões especiais antes da decisão normal
    CALL VERIFICA_PADROES_ESPECIAIS
    BTFSC STATUS, Z      ; Se Z=1, padrão especial foi encontrado e tratado
    GOTO LOOP_PRINCIPAL  ; Volta ao loop principal
    
    CALL DECIDE_MOVIMENTO
    CALL VERIFICA_CURVA
    GOTO LOOP_PRINCIPAL

; ====================
; PROCESSAMENTO DA TERCEIRA CURVA
; ====================
PROCESSAR_TERCEIRA_CURVA:
    ; Verifica se já processou a terceira curva
    MOVF SEGUNDA_FASE, W
    BTFSS STATUS, Z
    RETURN               ; Já está na segunda fase, retorna
    
    ; Para o carro
    CALL PARAR_CARRO_TEMPORARIO
    
    ; Espera 1 segundo
    CALL DELAY_1s
    
    ; Gira motor esquerdo até encontrar 010
    CALL GIRAR_ESQUERDA_ATE_010
    
    ; Lê chaves RA4 e RA5 para configurar próximas curvas
    CALL LER_CHAVES_CURVAS_4_5
    
    ; Marca que entrou na segunda fase
    MOVLW 0x01
    MOVWF SEGUNDA_FASE
    
    ; Zera contador para contar curvas 4, 5 e 6
    CLRF CONTADOR_CURVAS
    
    RETURN

; ====================
; GIRAR ESQUERDA ATÉ ENCONTRAR 010
; ====================
GIRAR_ESQUERDA_ATE_010:
    BANKSEL PORTA
    MOVLW B'00000001'    ; RA0=1, RA1=0 (motores 01 - motor esquerdo)
    MOVWF PORTA
    MOVLW B'01001000'    ; RB4=1, RB3=1 (rodas à esquerda)
    MOVWF PORTB
    
GIRO_ESQUERDA_LOOP:
    CALL LER_SENSORES
    MOVLW B'00000010'    ; Espera sensor central (010)
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO GIRO_ESQUERDA_LOOP
    
    ; Volta a andar reto
    CALL ANDAR_RETO
    RETURN

; ====================
; LER CHAVES PARA CURVAS 4 E 5
; ====================
LER_CHAVES_CURVAS_4_5:
    ; Lê RA4 (bit 4) e RA5 (bit 5)
    BANKSEL PORTA
    MOVLW B'00110000'     ; Máscara para RA4 e RA5
    ANDWF PORTA, W
    MOVWF CONFIG_CURVAS   ; Armazena configuração
    RETURN

; ====================
; VERIFICA PADRÕES ESPECIAIS
; ====================
VERIFICA_PADROES_ESPECIAIS:
    ; Padrão 000 -> motores 11 (andar reto)
    MOVLW B'00000000'
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO VERIFICA_001
    
    ; Padrão 000 encontrado
    CALL ANDAR_RETO
    BSF STATUS, Z        ; Seta flag Z=1 para indicar padrão tratado
    RETURN

VERIFICA_001:
    ; Padrão 001 -> motores 10 (virar à direita)
    MOVLW B'00000001'
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO VERIFICA_100
    
    ; Padrão 001 encontrado
    BANKSEL PORTA
    MOVLW B'00000010'    ; RA0=0, RA1=1 (motores 10)
    MOVWF PORTA
    MOVLW B'00110000'    ; RB5=1, RB4=1 (rodas à direita)
    MOVWF PORTB
    BSF STATUS, Z        ; Seta flag Z=1 para indicar padrão tratado
    RETURN

VERIFICA_100:
    ; Padrão 100 -> motores 01 (virar à esquerda)
    MOVLW B'00000100'
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO PADRAO_NAO_ENCONTRADO
    
    ; Padrão 100 encontrado
    BANKSEL PORTA
    MOVLW B'00000001'    ; RA0=1, RA1=0 (motores 01)
    MOVWF PORTA
    MOVLW B'01001000'    ; RB4=1, RB3=1 (rodas à esquerda)
    MOVWF PORTB
    BSF STATUS, Z        ; Seta flag Z=1 para indicar padrão tratado
    RETURN

PADRAO_NAO_ENCONTRADO:
    BCF STATUS, Z        ; Limpa flag Z=0 para indicar padrão não encontrado
    RETURN

; ====================
; DECISÃO DE MOVIMENTO
; ====================
DECIDE_MOVIMENTO:
    MOVLW B'00000010'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    CALL ANDAR_RETO
    
    MOVLW B'00000100'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    CALL AJUSTAR_ESQUERDA
    
    MOVLW B'00000001'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    CALL AJUSTAR_DIREITA
    RETURN

; ====================
; VERIFICAÇÃO DE CURVA
; ====================
VERIFICA_CURVA:
    ; Verifica se está na segunda fase
    MOVF SEGUNDA_FASE, W
    BTFSS STATUS, Z
    GOTO VERIFICA_CURVA_SEGUNDA_FASE
    
    ; Primeira fase: verifica TODOS os padrões de curva
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_PRIMEIRA_FASE
    
    MOVLW B'00000110'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_PRIMEIRA_FASE
    
    MOVLW B'00000011'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_PRIMEIRA_FASE
    
    RETURN

VERIFICA_CURVA_SEGUNDA_FASE:
    ; Segunda fase: verifica padrões de curva
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_SEGUNDA_FASE
    
    MOVLW B'00000110'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_SEGUNDA_FASE
    
    MOVLW B'00000011'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA_SEGUNDA_FASE
    
    RETURN

DETECTOU_CURVA_PRIMEIRA_FASE:
    ; Incrementa contador de curvas
    INCF CONTADOR_CURVAS, F
    
    ; Verifica qual curva está executando
    MOVLW 0x01
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO EXECUTAR_PRIMEIRA_CURVA
    
    MOVLW 0x02
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO EXECUTAR_SEGUNDA_CURVA
    
    ; Terceira curva: apenas conta, o PROCESSAR_TERCEIRA_CURVA vai tratar
    RETURN

DETECTOU_CURVA_SEGUNDA_FASE:
    ; Incrementa contador de curvas (curvas 4, 5, 6)
    INCF CONTADOR_CURVAS, F
    
    ; Verifica qual curva da segunda fase
    MOVLW 0x01
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO EXECUTAR_QUARTA_CURVA
    
    MOVLW 0x02
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO EXECUTAR_QUINTA_CURVA
    
    ; Se chegou aqui, é a SEXTA curva (CONTADOR_CURVAS = 3)
    GOTO PARAR_CARRO_FINAL

; ====================
; EXECUÇÃO DAS CURVAS - PRIMEIRA FASE
; ====================
EXECUTAR_PRIMEIRA_CURVA:
    ; Executa a primeira curva conforme novo padrão
    ; Verifica padrão dos sensores primeiro
    MOVLW B'00000011'      ; Padrão 011
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011_PRIMEIRA
    
    MOVLW B'00000110'      ; Padrão 110
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_110_PRIMEIRA
    
    ; Padrão 111 (todos ativos) - trata como 011
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011_PRIMEIRA
    
    RETURN

EXECUTAR_SEGUNDA_CURVA:
    ; Executa a segunda curva (seguindo normalmente a linha)
    ; Verifica padrão dos sensores primeiro
    MOVLW B'00000011'      ; Padrão 011
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011_SEGUNDA
    
    MOVLW B'00000110'      ; Padrão 110
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_110_SEGUNDA
    
    ; Padrão 111 (todos ativos) - trata como 011
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011_SEGUNDA
    
    RETURN

PADRAO_011_PRIMEIRA:
    ; Para padrão 011 (sensores direita ativos) na PRIMEIRA curva
    ; Verifica direção configurada
    BTFSC DIRECAO, 0        ; Verifica bit 0 da variável DIRECAO
    GOTO P011_ESQUERDA_PRIMEIRA
    
P011_DIREITA_PRIMEIRA:
    ; Caso 2 (RA2,RA3=01): 1ª curva padrão 011 → motores 10
    CALL VIRAR_DIREITA
    RETURN
    
P011_ESQUERDA_PRIMEIRA:
    ; Caso 4 (RA2,RA3=11): 1ª curva padrão 011 → motores 10  
    CALL VIRAR_DIREITA
    RETURN

PADRAO_110_PRIMEIRA:
    ; Para padrão 110 (sensores esquerda ativos) na PRIMEIRA curva
    ; Verifica direção configurada
    BTFSC DIRECAO, 0        ; Verifica bit 0 da variável DIRECAO
    GOTO P110_ESQUERDA_PRIMEIRA
    
P110_DIREITA_PRIMEIRA:
    ; Caso 1 (RA2,RA3=00): 1ª curva padrão 110 → motores 01
    CALL VIRAR_ESQUERDA
    RETURN
    
P110_ESQUERDA_PRIMEIRA:
    ; Caso 3 (RA2,RA3=10): 1ª curva padrão 110 → motores 01
    CALL VIRAR_ESQUERDA
    RETURN

PADRAO_011_SEGUNDA:
    ; Segunda curva com padrão 011: vira à direita (normalmente)
    CALL VIRAR_DIREITA
    RETURN

PADRAO_110_SEGUNDA:
    ; Segunda curva com padrão 110: vira à esquerda (normalmente)
    CALL VIRAR_ESQUERDA
    RETURN

; ====================
; EXECUÇÃO DAS CURVAS - SEGUNDA FASE
; ====================
EXECUTAR_QUARTA_CURVA:
    ; Quarta curva: depende de RA4,RA5
    ; Extrai bits RA4 e RA5 de CONFIG_CURVAS
    MOVF CONFIG_CURVAS, W
    ANDLW B'00110000'      ; Isola RA4 e RA5
    MOVWF TEMP
    
    ; Testa combinações
    ; (0,0) -> 00: motores 10
    ; (0,1) -> 01: motores 10  
    ; (1,0) -> 10: motores 01
    ; (1,1) -> 11: motores 01
    
    MOVLW B'00010000'      ; Testa se RA4=1 (bit 4)
    ANDWF TEMP, W
    BTFSS STATUS, Z
    GOTO QUARTA_CURVA_01   ; Se RA4=1, motores 01
    
    ; Se RA4=0, motores 10
    CALL VIRAR_DIREITA
    RETURN

QUARTA_CURVA_01:
    CALL VIRAR_ESQUERDA
    RETURN

EXECUTAR_QUINTA_CURVA:
    ; Quinta curva: depende de RA4,RA5
    ; Extrai bits RA4 e RA5 de CONFIG_CURVAS
    MOVF CONFIG_CURVAS, W
    ANDLW B'00110000'      ; Isola RA4 e RA5
    MOVWF TEMP
    
    ; Testa combinações para quinta curva
    ; (0,0) -> 00: motores 10
    ; (0,1) -> 01: motores 01  
    ; (1,0) -> 10: motores 01
    ; (1,1) -> 11: motores 10
    
    ; Primeiro testa (0,0)
    MOVLW B'00110000'
    SUBWF TEMP, W
    BTFSC STATUS, Z
    GOTO QUINTA_CURVA_10   ; (1,1) -> motores 10
    
    ; Testa (0,1) e (1,0)
    MOVLW B'00010000'      ; Testa RA4
    ANDWF TEMP, W
    BTFSS STATUS, Z
    GOTO RA4_1_QUINTA
    
    ; RA4=0
    MOVLW B'00100000'      ; Testa RA5
    ANDWF TEMP, W
    BTFSS STATUS, Z
    GOTO QUINTA_CURVA_01   ; (0,1) -> motores 01
    ; Se não, é (0,0) -> motores 10
    GOTO QUINTA_CURVA_10

RA4_1_QUINTA:
    ; RA4=1
    MOVLW B'00100000'      ; Testa RA5
    ANDWF TEMP, W
    BTFSS STATUS, Z
    GOTO QUINTA_CURVA_10   ; (1,1) -> motores 10
    ; Se não, é (1,0) -> motores 01
    GOTO QUINTA_CURVA_01

QUINTA_CURVA_10:
    CALL VIRAR_DIREITA
    RETURN

QUINTA_CURVA_01:
    CALL VIRAR_ESQUERDA
    RETURN

; ====================
; SUBROTINAS DE ENTRADA
; ====================
LER_SENSORES:
    BANKSEL PORTB
    MOVLW B'00000111'
    ANDWF PORTB, W
    MOVWF ESTADO_SENSORES
    RETURN

LER_CHAVES_E_DECIDE_DIRECAO:
    ; Lê RA2 e RA3 para determinar direção
    ; 00 (RA3=0, RA2=0): Caso 1 -> PADRÃO 110
    ; 01 (RA3=0, RA2=1): Caso 2 -> PADRÃO 011  
    ; 10 (RA3=1, RA2=0): Caso 3 -> PADRÃO 110
    ; 11 (RA3=1, RA2=1): Caso 4 -> PADRÃO 011
    
    ; Lê RA2 (bit 2) e RA3 (bit 3) da PORTA
    MOVLW B'00001100'     ; Máscara para RA3 (bit 3) e RA2 (bit 2)
    ANDWF PORTA, W
    MOVWF TEMP           ; Guarda temporariamente
    
    ; Testa RA3 (bit 3)
    BTFSC TEMP, 3        ; Testa bit 3 (RA3)
    GOTO RA3_1
    
RA3_0:                  ; RA3=0
    ; Se RA3=0: 00 ou 01
    BTFSC TEMP, 2        ; Testa RA2 (bit 2)
    GOTO CONFIG_01      ; RA2=1 -> 01 (Caso 2)
    GOTO CONFIG_00      ; RA2=0 -> 00 (Caso 1)

RA3_1:                  ; RA3=1
    ; Se RA3=1: 10 ou 11
    BTFSC TEMP, 2        ; Testa RA2 (bit 2)
    GOTO CONFIG_11      ; RA2=1 -> 11 (Caso 4)
    GOTO CONFIG_10      ; RA2=0 -> 10 (Caso 3)

CONFIG_00:             ; Caso 1: 00 -> Padrão 110
CONFIG_10:             ; Caso 3: 10 -> Padrão 110
    MOVLW 0x00          ; 0 = indica padrão 110
    MOVWF DIRECAO
    RETURN

CONFIG_01:             ; Caso 2: 01 -> Padrão 011
CONFIG_11:             ; Caso 4: 11 -> Padrão 011
    MOVLW 0x01          ; 1 = indica padrão 011
    MOVWF DIRECAO
    RETURN

; ====================
; SUBROTINAS DE SAÍDA
; ====================
ANDAR_RETO:
    BANKSEL PORTA
    MOVLW B'00000011'    ; RA0=1, RA1=1 (motores 11)
    MOVWF PORTA
    MOVLW B'00101000'    ; RB3=1, RB5=1
    MOVWF PORTB
    RETURN

AJUSTAR_ESQUERDA:
    BANKSEL PORTA
    MOVLW B'00000011'    ; RA0=1, RA1=1 (motores 11)
    MOVWF PORTA
    MOVLW B'01001000'    ; RB4=1, RB3=1
    MOVWF PORTB
    RETURN

AJUSTAR_DIREITA:
    BANKSEL PORTA
    MOVLW B'00000011'    ; RA0=1, RA1=1 (motores 11)
    MOVWF PORTA
    MOVLW B'00110000'    ; RB5=1, RB4=1
    MOVWF PORTB
    RETURN

VIRAR_ESQUERDA:
    BANKSEL PORTA
    MOVLW B'00000001'    ; RA0=1, RA1=0 (motores 01)
    MOVWF PORTA
    MOVLW B'00100100'    ; RB5=1, RB2=1
    MOVWF PORTB
    
    CALL DELAY_130ms
    
LOOP_ESQUERDA:
    CALL LER_SENSORES
    MOVLW B'00000010'    ; Espera sensor central (010)
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO LOOP_ESQUERDA
    
    ; Volta a andar reto
    CALL ANDAR_RETO
    RETURN

VIRAR_DIREITA:
    BANKSEL PORTA
    MOVLW B'00000010'    ; RA0=0, RA1=1 (motores 10)
    MOVWF PORTA
    MOVLW B'00100100'    ; RB5=1, RB2=1
    MOVWF PORTB
    
    CALL DELAY_130ms
    
LOOP_DIREITA:
    CALL LER_SENSORES
    MOVLW B'00000010'    ; Espera sensor central (010)
    SUBWF ESTADO_SENSORES, W
    BTFSS STATUS, Z
    GOTO LOOP_DIREITA
    
    ; Volta a andar reto
    CALL ANDAR_RETO
    RETURN

; ====================
; SUBROTINAS DE DELAY
; ====================
DELAY_130ms:
    BANKSEL OPTION_REG
    MOVLW B'11010111'
    MOVWF OPTION_REG
    BANKSEL TMR0
    MOVLW 0x01
    MOVWF TMR0
    MOVLW 0x08
    MOVWF CONTADOR_DELAY
    
DELAY_LOOP:
    BTFSS INTCON, 2
    GOTO DELAY_LOOP
    BCF INTCON, 2
    MOVLW 0x01
    MOVWF TMR0
    DECFSZ CONTADOR_DELAY, F
    GOTO DELAY_LOOP
    RETURN

DELAY_1s:
    ; Delay de aproximadamente 1 segundo
    MOVLW 0x08
    MOVWF CONTADOR_1S
DELAY_1s_LOOP:
    CALL DELAY_130ms
    DECFSZ CONTADOR_1S, F
    GOTO DELAY_1s_LOOP
    RETURN

; ====================
; ROTINAS DE PARADA
; ====================
PARAR_CARRO_TEMPORARIO:
    BANKSEL PORTA
    MOVLW B'00000000'    ; RA0=0, RA1=0 (motores 00) - PARA!
    MOVWF PORTA
    MOVLW B'10000000'    ; RB7=1 (LED ligado)
    MOVWF PORTB
    RETURN

PARAR_CARRO_FINAL:
    BANKSEL PORTA
    MOVLW B'00000000'    ; RA0=0, RA1=0 (motores 00) - PARA!
    MOVWF PORTA
    MOVLW B'11000000'    ; RB7=1, RB6=1 (dois LEDs ligados)
    MOVWF PORTB
FIM:
    GOTO FIM

END