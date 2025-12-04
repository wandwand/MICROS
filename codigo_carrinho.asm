;=============================================================================
; Robô Seguidor de Linha - PIC16F628A (Código Corrigido para MPLAB/mpasmx)
;=============================================================================

        LIST        p=16F628A
        #include    <p16f628a.inc>

        __CONFIG _INTOSC_OSC_NOCLKOUT & _WDT_OFF & _PWRTE_OFF & _MCLRE_OFF & _BODEN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

;=============================================================================
; Definição de Variáveis
;=============================================================================
CBLOCK  0x70
    AT0         ; Contador de atraso nível 1
    AT1         ; Contador de atraso nível 2
    AT2         ; Contador de atraso nível 3
ENDC

CONT    EQU     0x20    ; Contador de estados para detecção de obstáculos
CURVA   EQU     0x21    ; Contador de intersecções

; Sensores (bits de PORTB)
S_ESQ      EQU 0        ; RB0 - sensor esquerdo
S_DIR      EQU 1        ; RB1 - sensor direito
S_FRENTE   EQU 2        ; RB2 - sensor do meio (centro)

; Motores (bits de PORTB)
M_E        EQU 4        ; Motor esquerdo frente (RB4)
M_D        EQU 5        ; Motor direito frente (RB5)
M_REV_E    EQU 6        ; Motor esquerdo reverso (RB6)
M_REV_D    EQU 7        ; Motor direito reverso (RB7)

; LEDs (bits de PORTA)
LED00      EQU 0        ; RA0
LED01      EQU 1        ; RA1
LED10      EQU 2        ; RA2
LED11      EQU 3        ; RA3
LED_FIM    EQU 4        ; RA4 (open-drain no 16F628A - atenção ao hardware)


;=============================================================================
; Vetores
;=============================================================================
        ORG 0x000
        GOTO INICIO

        ORG 0x004
        RETFIE

;=============================================================================
; Inicialização
;=============================================================================
INICIO:

        ; Configura TRISB: RB0-RB2 entradas, RB3-RB7 saídas
        BANKSEL TRISB
        MOVLW   b'00000111'     ; 1=entrada, 0=saida
        MOVWF   TRISB

        ; Configura TRISA: tudo saída (atenção RA4 = open-drain)
        BANKSEL TRISA
        CLRF    TRISA

        ; Desativa comparadores analógicos
        BANKSEL CMCON
        MOVLW   0x07
        MOVWF   CMCON

        ; Zera portas
        BANKSEL PORTA
        CLRF    PORTA

        BANKSEL PORTB
        CLRF    PORTB

        ; Inicializa variáveis
        CLRF    CONT
        CLRF    CURVA

;=============================================================================
; Loop Principal
;=============================================================================
MAIN:

        ; --- 1) CONDIÇÃO DE PARADA: AMBOS SENSORES LATERAIS ATIVOS ---
        BANKSEL PORTB
        BTFSS   PORTB, S_ESQ       ; se ESQ=0, continua seguindo
        GOTO    SEGUE
        BTFSS   PORTB, S_DIR       ; se DIR=0, continua seguindo
        GOTO    SEGUE

        ; Se chegou aqui: ambos sensores laterais = 1 → PARAR
PARAR:
        BANKSEL PORTB
        BCF     PORTB, M_E
        BCF     PORTB, M_D
        BCF     PORTB, M_REV_E
        BCF     PORTB, M_REV_D
        GOTO    PARAR              ; trava parado (laço intencional)


;=============================================================================
; LÓGICA PRINCIPAL DE SEGUIMENTO DE LINHA
;=============================================================================
SEGUE:
        BANKSEL PORTB

        ; --- 2) Linha sob o sensor central → andar reto ---
        BTFSC   PORTB, S_FRENTE
        GOTO    ANDAR_RETO

        ; --- 3) Saiu da linha → corrigir usando sensores laterais ---
        BTFSC   PORTB, S_ESQ
        GOTO    AJUSTE_ESQ

        BTFSC   PORTB, S_DIR
        GOTO    AJUSTE_DIR

        ; --- 4) Nenhum sensor detecta linha → PERDEU_LINHA ---
PERDEU_LINHA:
        BANKSEL PORTB
        BCF     PORTB, M_E        ; desliga motor esquerdo
        BSF     PORTB, M_D        ; motor direito ligado → curva para direita
        GOTO    MAIN


;=============================================================================
; Movimentos
;=============================================================================
ANDAR_RETO:
        BANKSEL PORTB
        BSF     PORTB, M_E
        BSF     PORTB, M_D
        BCF     PORTB, M_REV_E
        BCF     PORTB, M_REV_D
        GOTO    MAIN

AJUSTE_ESQ:
        BANKSEL PORTB
        BCF     PORTB, M_E
        BSF     PORTB, M_D
        BCF     PORTB, M_REV_E
        BCF     PORTB, M_REV_D
        GOTO    MAIN

AJUSTE_DIR:
        BANKSEL PORTB
        BSF     PORTB, M_E
        BCF     PORTB, M_D
        BCF     PORTB, M_REV_E
        BCF     PORTB, M_REV_D
        GOTO    MAIN

        END
