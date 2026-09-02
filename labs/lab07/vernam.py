def xor(text, key):
    result = []
    for i in range(len(text)):
        result.append(chr(ord(text[i]) ^ ord(key[i % len(key)])))
    return ''.join(result)

def hex_to_str(hex_text):
    hex_text = hex_text.replace(' ', '')
    return bytes.fromhex(hex_text).decode('utf-8', errors='ignore')

def str_to_hex(text):
    return ' '.join(f'{ord(c):02X}' for c in text)

while True:
    print("\n1. Зашифровать")
    print("2. Расшифровать")
    print("3. Найти ключ")
    print("4. Найти ключ для 'С Новым Годом, друзья'")
    print("5. Выход")

    choice = input("Выбор: ")

    if choice == '1':
        text = input("Текст: ")
        key = input("Ключ: ")
        if len(key) < len(text):
            print("Ключ слишком короткий!")
            continue
        encrypted = xor(text, key[:len(text)])
        print(f"Зашифровано: {encrypted}")
        print(f"HEX: {str_to_hex(encrypted)}")

    elif choice == '2':
        text = input("Зашифрованный текст: ")
        key = input("Ключ: ")
        if len(key) < len(text):
            print("Ключ слишком короткий!")
            continue
        decrypted = xor(text, key[:len(text)])
        print(f"Расшифровано: {decrypted}")

    elif choice == '3':
        text = input("Исходный текст: ")
        encrypted = input("Зашифрованный текст: ")
        if len(text) != len(encrypted):
            print("Длины не совпадают!")
            continue
        key = xor(text, encrypted)
        print(f"Ключ: {key}")
        print(f"Ключ HEX: {str_to_hex(key)}")

    elif choice == '4':
        target = "С Новым Годом, друзья"
        print(f"Цель: {target}")
        encrypted = input("Введите зашифрованный текст (HEX): ").replace(' ', '')
        try:
            encrypted_text = hex_to_str(encrypted)
            if len(target) != len(encrypted_text):
                print("Длины не совпадают!")
                continue
            key = xor(target, encrypted_text)
            print(f"Ключ: {key}")
            print(f"Ключ HEX: {str_to_hex(key)}")
            decrypted = xor(encrypted_text, key)
            print(f"Расшифровано: {decrypted}")
        except:
            print("Неверный HEX!")

    elif choice == '5':
        print("До свидания!")
        break

    else:
        print("Неверный выбор!")
