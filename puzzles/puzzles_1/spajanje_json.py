import os
import json
import tkinter as tk
from tkinter import filedialog, simpledialog, messagebox, Toplevel, Checkbutton, Button, Frame, Scrollbar, Canvas

def merge_json_files():
    """
    Glavna funkcija koja vodi korisnika kroz proces spajanja JSON fajlova.
    """
    # 1. Kreiranje glavnog prozora i sakrivanje
    root = tk.Tk()
    root.withdraw()

    # 2. Pitaj korisnika da izabere folder
    folder_path = filedialog.askdirectory(title="Izaberite folder sa JSON fajlovima")
    if not folder_path:
        messagebox.showinfo("Otkazano", "Operacija otkazana.")
        return

    # 3. Pronađi sve JSON fajlove u folderu
    try:
        json_files = [f for f in os.listdir(folder_path) if f.endswith('.json')]
        if not json_files:
            messagebox.showerror("Greška", f"Nema .json fajlova u folderu:\n{folder_path}")
            return
    except Exception as e:
        messagebox.showerror("Greška", f"Nije moguće pročitati folder: {e}")
        return

    # 4. Prikaz prozora za izbor fajlova
    selected_files = ask_for_files_to_merge(json_files)
    if not selected_files:
        messagebox.showinfo("Otkazano", "Niste izabrali nijedan fajl. Operacija otkazana.")
        return
        
    # 5. Pitaj za naziv izlaznog fajla
    output_filename = simpledialog.askstring("Izlazni fajl", "Unesite naziv za spojeni JSON fajl (bez .json):")
    if not output_filename:
        messagebox.showinfo("Otkazano", "Niste uneli naziv fajla. Operacija otkazana.")
        return
    
    # Dodaj .json ekstenziju ako ne postoji
    if not output_filename.endswith('.json'):
        output_filename += '.json'

    # --- Procesiranje ---
    combined_data = []
    
    # 6. Učitavanje i spajanje podataka
    for file_name in selected_files:
        file_path = os.path.join(folder_path, file_name)
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
                if isinstance(data, list):
                    combined_data.extend(data)
                else:
                    # Ako JSON nije lista, preskačemo ga uz upozorenje
                    print(f"Upozorenje: Fajl '{file_name}' ne sadrži listu i biće preskočen.")
        except json.JSONDecodeError:
            print(f"Greška: Fajl '{file_name}' nije validan JSON i biće preskočen.")
        except Exception as e:
            print(f"Greška pri čitanju fajla '{file_name}': {e}")
    
    # 7. Menjanje ID-jeva
    current_id = 1
    for item in combined_data:
        # Pretpostavljamo da je svaki 'item' rečnik (dictionary)
        if isinstance(item, dict):
            item['id'] = current_id
            current_id += 1

    # 8. Snimanje spojenog fajla
    output_file_path = os.path.join(folder_path, output_filename)
    try:
        with open(output_file_path, 'w', encoding='utf-8') as f:
            # indent=4 za lepši ispis, ensure_ascii=False za ispravan prikaz naših slova (č,ć,š,đ,ž)
            json.dump(combined_data, f, indent=4, ensure_ascii=False)
        
        messagebox.showinfo("Uspeh!", f"Fajlovi su uspešno spojeni!\n\nSačuvano kao: {output_file_path}")
    except Exception as e:
        messagebox.showerror("Greška pri snimanju", f"Nije moguće sačuvati fajl: {e}")

def ask_for_files_to_merge(file_list):
    """
    Pomoćna funkcija koja kreira prozor sa checkbox-ovima za izbor fajlova.
    """
    dialog = Toplevel()
    dialog.title("Izaberite fajlove za spajanje")

    # Okvir sa scrollbar-om za slučaj da ima previše fajlova
    main_frame = Frame(dialog)
    main_frame.pack(fill="both", expand=True)
    
    canvas = Canvas(main_frame)
    canvas.pack(side="left", fill="both", expand=True)

    scrollbar = Scrollbar(main_frame, orient="vertical", command=canvas.yview)
    scrollbar.pack(side="right", fill="y")
    
    canvas.configure(yscrollcommand=scrollbar.set)
    
    content_frame = Frame(canvas)
    canvas.create_window((0, 0), window=content_frame, anchor="nw")

    # Dictionary za čuvanje stanja svakog checkbox-a
    choices = {file_name: tk.IntVar() for file_name in file_list}
    for file_name in file_list:
        cb = Checkbutton(content_frame, text=file_name, variable=choices[file_name])
        cb.pack(anchor='w', padx=10, pady=2)

    selected = []
    def on_confirm():
        nonlocal selected
        selected = [file_name for file_name, var in choices.items() if var.get() == 1]
        dialog.destroy()
        
    def on_close():
        nonlocal selected
        selected = [] # Prazna lista ako korisnik zatvori prozor
        dialog.destroy()

    confirm_button = Button(dialog, text="Spoji izabrane", command=on_confirm)
    confirm_button.pack(pady=10)
    
    dialog.protocol("WM_DELETE_WINDOW", on_close) # Ručka za zatvaranje prozora na 'X'
    
    # Prilagodi veličinu prozora i scroll region
    content_frame.update_idletasks()
    canvas.config(scrollregion=canvas.bbox("all"))

    # Čekaj da se prozor zatvori pre nastavka
    dialog.wait_window()
    return selected

if __name__ == "__main__":
    merge_json_files()