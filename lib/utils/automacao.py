import sys
import time
import win32gui
import win32con
import win32api

# Configurações de atraso
DELAY_TAB = 0.15
DELAY_KEY = 0.05

def pressionar_tecla_vsc(vk_code):
    """Simula o pressionamento físico de uma tecla."""
    win32api.keybd_event(vk_code, 0, 0, 0) # Down
    time.sleep(DELAY_KEY)
    win32api.keybd_event(vk_code, 0, win32con.KEYEVENTF_KEYUP, 0) # Up
    time.sleep(DELAY_KEY)

def digitar_texto_vsc(texto):
    """Digita texto simulando entrada de hardware caractere por caractere."""
    for char in str(texto):
        # Converte para Virtual Key Code compatível com layout do teclado
        vk = win32api.VkKeyScan(char)
        if vk == -1: continue # Ignora caracteres não mapeáveis
        
        # Verifica se precisa de Shift (bit alto de vk)
        shift = (vk >> 8) & 1
        if shift: win32api.keybd_event(win32con.VK_SHIFT, 0, 0, 0)
        
        win32api.keybd_event(vk & 0xFF, 0, 0, 0)
        win32api.keybd_event(vk & 0xFF, 0, win32con.KEYEVENTF_KEYUP, 0)
        
        if shift: win32api.keybd_event(win32con.VK_SHIFT, 0, win32con.KEYEVENTF_KEYUP, 0)
        time.sleep(0.03)

def lancar_produto():
    if len(sys.argv) < 6: return

    codigo, quantidade, valor_unit, base_calc, icms = sys.argv[1:6]

    # 1. Localiza e traz a janela para frente
    # DICA: Use o título parcial que você vê na barra superior do sistema
    hwnd = win32gui.FindWindow(None, 'Resulthbusiness')
    if not hwnd:
        print("Janela do sistema não encontrada.")
        return

    win32gui.ShowWindow(hwnd, win32con.SW_RESTORE)
    win32gui.SetForegroundWindow(hwnd)
    time.sleep(1.5) # Aguarda o sistema ganhar foco real

    # --- INÍCIO DA SEQUÊNCIA SOLICITADA ---

    # Alt + I (Inserir)
    win32api.keybd_event(win32con.VK_MENU, 0, 0, 0) # Alt Down
    pressionar_tecla_vsc(ord('I'))
    win32api.keybd_event(win32con.VK_MENU, 0, win32con.KEYEVENTF_KEYUP, 0) # Alt Up
    time.sleep(0.5)

    # [código] + enter
    digitar_texto_vsc(codigo)
    pressionar_tecla_vsc(win32con.VK_RETURN)
    time.sleep(0.5)

    # [quantidade] + tab x2
    digitar_texto_vsc(quantidade.replace('.', ','))
    for _ in range(2): pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # [valor unitário] + tab x5
    digitar_texto_vsc(valor_unit.replace('.', ','))
    for _ in range(5): pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # "27,32" + tab
    digitar_texto_vsc("27,32")
    pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # [base de calculo] + tab
    digitar_texto_vsc(base_calc.replace('.', ','))
    pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # "20,5" + tab
    digitar_texto_vsc("20,5")
    pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # [icms] + tab x3
    digitar_texto_vsc(icms.replace('.', ','))
    for _ in range(3): pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # "020" + tab x14
    digitar_texto_vsc("020")
    for _ in range(14): pressionar_tecla_vsc(win32con.VK_TAB); time.sleep(DELAY_TAB)

    # "49" + enter
    digitar_texto_vsc("49")
    pressionar_tecla_vsc(win32con.VK_RETURN)
    time.sleep(0.8)

    # Alt + O (Confirmar)
    win32api.keybd_event(win32con.VK_MENU, 0, 0, 0)
    pressionar_tecla_vsc(ord('O'))
    win32api.keybd_event(win32con.VK_MENU, 0, win32con.KEYEVENTF_KEYUP, 0)

if __name__ == "__main__":
    lancar_produto()