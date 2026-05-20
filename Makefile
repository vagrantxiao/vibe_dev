m=$(shell date)

git:
	git add .
	git commit -m "$(m)"
	git push origin main
