case $(jq -r '.KeyboardLayoutSwitched.idx') in
  0) niriu.sh conf --rm 'layout { border { on; width 4; active-color "blue"; }; }';;
  *) niriu.sh conf --add 'layout { border { on; width 4; active-color "blue"; }; }';;
esac
