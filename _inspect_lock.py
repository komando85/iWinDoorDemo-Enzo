import zipfile
with zipfile.ZipFile("Experts.zip") as z:
    lines=z.read("ربات مرجع/TFlab New EA V.5.mq5").decode("utf-8-sig",errors="replace").splitlines()
    for i in range(1473,1518):
        print(f"{i+1}: {lines[i]}")
