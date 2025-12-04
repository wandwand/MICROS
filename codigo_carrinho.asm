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
    FLAG        ; Variável de flag para controle (bit0 = primeira vez 11, bit1 = segunda vez 11)
    TEMP        ; Variável temporária
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

; Bits da variável FLAG
PRIMEIRA_VEZ EQU 0      ; Bit 0 - primeira vez encontrou 11
SEGUNDA_VEZ  EQU 1      ; Bit 1 - segunda vez encontrou 11

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
        CLRF    FLAG

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
; LÓGICA PRINCIPAL DE SEGUIMENTO DE LINHA COM CONDIÇÃO ESPECIAL
;=============================================================================
SEGUE:
        BANKSEL PORTB
        
        ; --- Primeiro verifica condição especial: sensor esquerdo e meio = 11 ---
        ; Verifica se sensor esquerdo = 1 E sensor meio = 1
        BTFSS   PORTB, S_ESQ       ; Verifica se esquerdo = 1
        GOTO    LOGICA_NORMAL      ; Se não, vai para lógica normal
        
        BTFSS   PORTB, S_FRENTE    ; Verifica se meio = 1
        GOTO    LOGICA_NORMAL      ; Se não, vai para lógica normal
        
        ; --- Se chegou aqui: ESQUERDO=1 e MEIO=1 (condição 11) ---
        
        ; Verifica se já foi primeira vez
        BANKSEL FLAG
        BTFSS   FLAG, PRIMEIRA_VEZ
        GOTO    PRIMEIRA_VEZ_11    ; Primeira vez encontrando 11
        
        ; Se já foi primeira vez, verifica se é segunda vez
        BTFSS   FLAG, SEGUNDA_VEZ
        GOTO    SEGUNDA_VEZ_11     ; Segunda vez encontrando 11
        
        ; Se já foi segunda vez, continua parado
        GOTO    PARAR

PRIMEIRA_VEZ_11:
        ; Marca que encontrou primeira vez
        BANKSEL FLAG
        BSF     FLAG, PRIMEIRA_VEZ
        
        ; Vai para ajuste esquerda e espera até ver apenas o meio
        CALL    AJUSTE_ESPERA_MEIO
        
        ; Volta para MAIN
        GOTO    MAIN

SEGUNDA_VEZ_11:
        ; Marca que encontrou segunda vez
        BANKSEL FLAG
        BSF     FLAG, SEGUNDA_VEZ
        
        ; Para permanentemente
        GOTO    PARAR

LOGICA_NORMAL:
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
        
        ; Verifica se durante a curva encontra condição 11 novamente
        CALL    VERIFICA_11_DURANTE_CURVA
        GOTO    MAIN

;=============================================================================
; Subrotina: Verifica condição 11 durante a curva
;=============================================================================
VERIFICA_11_DURANTE_CURVA:
        BANKSEL PORTB
        ; Verifica se sensor esquerdo = 1 E sensor meio = 1
        BTFSS   PORTB, S_ESQ       ; Verifica se esquerdo = 1
        RETLW   0                  ; Se não, retorna
        
        BTFSS   PORTB, S_FRENTE    ; Verifica se meio = 1
        RETLW   0                  ; Se não, retorna
        
        ; Se encontrou 11 durante a curva
        ; Verifica se já foi primeira vez
        BANKSEL FLAG
        BTFSS   FLAG, PRIMEIRA_VEZ
        GOTO    MARCA_PRIMEIRA_VEZ
        
        ; Se já foi primeira vez, marca segunda vez
        BSF     FLAG, SEGUNDA_VEZ
        GOTO    PARAR
        
MARCA_PRIMEIRA_VEZ:
        BSF     FLAG, PRIMEIRA_VEZ
        RETLW   0

;=============================================================================
; Subrotina: Ajuste esquerda e espera até ver apenas o meio
;=============================================================================
AJUSTE_ESPERA_MEIO:
        BANKSEL PORTB
        
        ; Ajusta para esquerda
        BCF     PORTB, M_E
        BSF     PORTB, M_D
        BCF     PORTB, M_REV_E
        BCF     PORTB, M_REV_D
        
        ; Pequeno delay para iniciar movimento
        CALL    DELAY_PEQUENO
        
ESPERA_MEIO_LOOP:
        ; Verifica se esquerdo = 0 e meio = 1
        BTFSC   PORTB, S_ESQ      ; Se esquerdo = 1, continua ajustando
        GOTO    CONTINUA_AJUSTE
        
        BTFSS   PORTB, S_FRENTE   ; Se meio = 0, continua ajustando
        GOTO    CONTINUA_AJUSTE
        
        ; Quando chega aqui: esquerdo=0 e meio=1
        ; Para os motores
        BCF     PORTB, M_E
        BCF     PORTB, M_D
        
        ; Delay para estabilização
        CALL    DELAY_PEQUENO
        
        ; Verifica novamente para confirmar
        BTFSC   PORTB, S_ESQ
        GOTO    CONTINUA_AJUSTE
        
        BTFSS   PORTB, S_FRENTE
        GOTO    CONTINUA_AJUSTE
        
        ; Confirmação ok, retorna
        RETLW   0

CONTINUA_AJUSTE:
        ; Continua ajustando para esquerda
        BCF     PORTB, M_E
        BSF     PORTB, M_D
        GOTO    ESPERA_MEIO_LOOP

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

;=============================================================================
; Subrotinas de Delay
;=============================================================================
DELAY_PEQUENO:
        MOVLW   .50
        MOVWF   AT1
DELAY_P1:
        MOVLW   .100
        MOVWF   AT0
DELAY_P0:
        DECFSZ  AT0, F
        GOTO    DELAY_P0
        DECFSZ  AT1, F
        GOTO    DELAY_P1
        RETURN

DELAY:
        MOVLW   .100
        MOVWF   AT2
DELAY_LOOP2:
        MOVLW   .100
        MOVWF   AT1
DELAY_LOOP1:
        MOVLW   .10
        MOVWF   AT0
DELAY_LOOP0:
        DECFSZ  AT0, F
        GOTO    DELAY_LOOP0
        DECFSZ  AT1, F
        GOTO    DELAY_LOOP1
        DECFSZ  AT2, F
        GOTO    DELAY_LOOP2
        RETURN

        END