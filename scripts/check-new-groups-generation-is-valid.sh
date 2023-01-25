#!/bin/bash

# Checks that new group generators are valid 
# to be run by the CI on a new pull request

MAX_NB_OF_GROUP_GENERATORS_TO_CHECK=20

computeNbOfNewGroupGenerators() {
  new_group_generators=$@
  nb_of_new_group_generators=$(echo $new_group_generators | wc -w)

  if [ $nb_of_new_group_generators -eq 0 ]; then
    echo "No new group generator to check"
    exit 0
  fi
}

generateGroup() {
  group_generator_name=$1
  echo "Checking that $group_generator_name is valid..."
  yarn generate-group $group_generator_name; 
  if [ $? -ne 0 ]; then
    echo -e "Group generator '$group_generator_name' is not valid\n";
    exit 1
  fi
  echo -e "Group generator '$group_generator_name' is valid ✨\n";
}

# To avoid spamming the CI with too many group generators in a single PR
spamProtection() {
  counter=0
  for group_generator_name in $1; 
  do 
    if [ $counter -eq $MAX_NB_OF_GROUP_GENERATORS_TO_CHECK ]; then
      echo "Spam protection: $MAX_NB_OF_GROUP_GENERATORS_TO_CHECK group generators to check, abort checking."
      exit 0
    fi
    counter=$((counter+1))
  done
}

main() {
  new_group_generators=$(git diff origin/main HEAD -- group-generators/generators/index.ts | grep '^+  "' | awk -F'"' '{print $2}')
  new_group_generators_filenames=$(git diff origin/main HEAD -- group-generators/generators/index.ts | grep '^+import ' | awk -F'"' '{print $2}' | awk -F'/' '{print $2}')

  # Check that there is at least one new group generator
  computeNbOfNewGroupGenerators $new_group_generators

  # To avoid spamming the CI with too many group generators in a single PR
  spamProtection $new_group_generators

  # generate the groups that the new group generators depend on
  for new_group_generators_filename in $new_group_generators_filenames; 
  do
    filename="group-generators/generators/${new_group_generators_filename}/index.ts"
    dependsOnGroup=$(grep "dependsOn" $filename | grep -o '".*"' | sed 's/"//g' | sed 's/,/ /g')
    if [ -n "$dependsOnGroup" ]; then
      for group in $dependsOnGroup; do
        echo "Group generator in '$filename' depends on '$group'"
        generateGroup $group
      done
    fi
  done

  # check that the new group generators are valid
  for group_generator_name in $new_group_generators; 
  do 
    generateGroup $group_generator_name
  done

  exit 0
}

main