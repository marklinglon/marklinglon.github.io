rsync -avzP --exclude=node_modules /mnt/e/clash/test/blog/ /mnt/e/clash/test/marklinglon.github.io/
cd /mnt/e/clash/test/marklinglon.github.io/
git add *;git commit -m "update";git push origin main:main
