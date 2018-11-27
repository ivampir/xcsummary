#!/bin/sh

HOOK_FILENAME="./.git/hooks/prepare-commit-msg"
if [ ! -d "./.git" ]; then
  echo "This is not git repository root"  
  exit
fi

if [ ! -d "./.git/hooks" ]; then
  echo "Creating hooks directory" 
  mkdir ./.git/hooks
fi

echo '#!/bin/sh                                                                                         
                                                                                                   
BRANCH_NAME=$(git symbolic-ref --short HEAD)                                                        
BRANCH_NAME="${BRANCH_NAME##*/}"                                                                    
                                                                                                   
BRANCH_IN_COMMIT=$(grep -c "\[$BRANCH_NAME\]" $1)                                                  
                                                                                                    
if [ -n "$BRANCH_NAME" ] && ! [[ $BRANCH_EXCLUDED -eq 1 ]] && ! [[ $BRANCH_IN_COMMIT -ge 1 ]]; then
    echo "($BRANCH_NAME)" >> $1
fi
' > $HOOK_FILENAME

echo "Created hook $HOOK_FILENAME"
chmod +x $HOOK_FILENAME                                                                                 
echo "Done."                                                                                            