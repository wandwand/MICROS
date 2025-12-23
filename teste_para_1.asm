INCLUDE <p16f628a.inc>
__CONFIG _FOSC_INTOSCIO & _WDTE_OFF & _PWRTE_ON & _MCLRE_OFF & _BOREN_OFF & _LVP_OFF & _CPD_OFF & _CP_OFF

; ====================
; VARIÁVEIS
; ====================
ESTADO_SENSORES    EQU 0x70    ; Estado dos sensores (PORTB)
CONTADOR_CURVAS    EQU 0x72    ; Quantidade de curvas realizadas
CONTADOR_DELAY     EQU 0x73    ; Contador para delays
DIRECAO           EQU 0x74    ; Direção da 1ª curva (0=direita, 1=esquerda)

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
    
    ; Verifica se já fez 2 curvas
    MOVLW 0x02
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO PARAR_CARRO    ; Se já tem 2 curvas, PARA IMEDIATAMENTE
    
    CALL DECIDE_MOVIMENTO
    CALL VERIFICA_CURVA
    GOTO LOOP_PRINCIPAL

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
    ; Verifica TODOS os padrões de curva
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA
    
    MOVLW B'00000110'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA
    
    MOVLW B'00000011'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO DETECTOU_CURVA
    
    RETURN

DETECTOU_CURVA:
    ; Incrementa contador de curvas
    INCF CONTADOR_CURVAS, F
    
    ; Verifica se é a PRIMEIRA curva
    MOVLW 0x01
    SUBWF CONTADOR_CURVAS, W
    BTFSC STATUS, Z
    GOTO EXECUTAR_PRIMEIRA_CURVA
    
    ; Se chegou aqui, é a SEGUNDA curva
    ; Segunda curva: NÃO executa movimento, apenas conta
    ; O loop principal vai detectar contador=2 e parar
    RETURN

EXECUTAR_PRIMEIRA_CURVA:
    ; Executa a primeira curva conforme novo padrão
    ; Verifica padrão dos sensores primeiro
    MOVLW B'00000011'      ; Padrão 011
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011
    
    MOVLW B'00000110'      ; Padrão 110
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_110
    
    ; Padrão 111 (todos ativos) - trata como 011
    MOVLW B'00000111'
    SUBWF ESTADO_SENSORES, W
    BTFSC STATUS, Z
    GOTO PADRAO_011
    
    RETURN

PADRAO_011:
    ; Para padrão 011 (sensores direita ativos)
    ; Verifica direção configurada
    BTFSC DIRECAO, 0        ; Verifica bit 0 da variável DIRECAO
    GOTO P011_ESQUERDA
    
P011_DIREITA:
    ; Caso 2 (RA2,RA3=01): 1ª curva padrão 011→motores 10
    CALL VIRAR_DIREITA
    RETURN
    
P011_ESQUERDA:
    ; Caso 4 (RA2,RA3=11): 1ª curva padrão 011→motores 10  
    CALL VIRAR_DIREITA
    RETURN

PADRAO_110:
    ; Para padrão 110 (sensores esquerda ativos)
    ; Verifica direção configurada
    BTFSC DIRECAO, 0        ; Verifica bit 0 da variável DIRECAO
    GOTO P110_ESQUERDA
    
P110_DIREITA:
    ; Caso 1 (RA2,RA3=00): 1ª curva padrão 110→motores 01
    CALL VIRAR_ESQUERDA
    RETURN
    
P110_ESQUERDA:
    ; Caso 3 (RA2,RA3=10): 1ª curva padrão 110→motores 01
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
    ; Novo padrão:
    ; 00 (RA3=0, RA2=0): Caso 1 -> PADRÃO 110
    ; 01 (RA3=0, RA2=1): Caso 2 -> PADRÃO 011  
    ; 10 (RA3=1, RA2=0): Caso 3 -> PADRÃO 110
    ; 11 (RA3=1, RA2=1): Caso 4 -> PADRÃO 011
    
    ; Lê RA2 (bit 3) e RA3 (bit 4) da PORTA
    ; Nota: No PIC16F628A, PORTA bits:
    ; RA0, RA1, RA2, RA3, RA4, RA5, RA6, RA7
    ; Mas RA6 e RA7 não existem neste modelo
    
    MOVLW B'00011000'     ; Máscara para RA3 (bit 3) e RA2 (bit 2)
    ; CORREÇÃO: No PIC16F628A, RA2 é bit 2, RA3 é bit 3
    ANDWF PORTA, W
    MOVWF 0x71           ; Guarda temporariamente
    
    ; Extrai os bits para teste
    ; Bit 2 = RA2, Bit 3 = RA3
    
    ; Testa RA3 (bit 3)
    BTFSC 0x71, 3        ; Testa bit 3 (RA3)
    GOTO RA3_1
    
RA3_0:                  ; RA3=0
    ; Se RA3=0: 00 ou 01
    BTFSC 0x71, 2        ; Testa RA2 (bit 2)
    GOTO CONFIG_01      ; RA2=1 -> 01 (Caso 2)
    GOTO CONFIG_00      ; RA2=0 -> 00 (Caso 1)

RA3_1:                  ; RA3=1
    ; Se RA3=1: 10 ou 11
    BTFSC 0x71, 2        ; Testa RA2 (bit 2)
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

; ====================
; FIM DO PROGRAMA
; ====================
PARAR_CARRO:
    BANKSEL PORTA
    MOVLW B'00000000'    ; RA0=0, RA1=0 (motores 00) - PARA!
    MOVWF PORTA
    MOVLW B'10000000'    ; RB7=1 (LED ligado)
    MOVWF PORTB
FIM:
    GOTO FIM

END