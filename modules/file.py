import os

def create_same_file_in_multiple_directories(file_name, content, directories):
    """
    Creates a file with the specified name and content in each of the given directories.

    Args:
        file_name (str): The name of the file to create (e.g., "my_file.txt").
        content (str): The content to write into the file.
        directories (list): A list of directory paths where the file should be created.
    """
    for directory in directories:
        # Ensure the directory exists; create it if it doesn't
        os.makedirs(directory, exist_ok=True)

        # Construct the full path to the new file
        file_path = os.path.join(directory, file_name)

        try:
            # Open the file in write mode and write the content
            with open(file_path, 'w') as f:
                f.write(content)
            print(f"Successfully created '{file_name}' in '{directory}'")
        except IOError as e:
            print(f"Error creating '{file_name}' in '{directory}': {e}")

# Example Usage:
if __name__ == "__main__":
    target_directories = [
        "./alb",
        "./ecs",
        "./iam",
        "./lambda",
        "./networking"
    ]
    file_to_create = "main.tf"
    file_content = ""

    create_same_file_in_multiple_directories(file_to_create, file_content, target_directories)

    # You can also create a different file in the same directories or new ones
    another_file = "variables.tf"
    another_content = ""
    create_same_file_in_multiple_directories(another_file, another_content, target_directories)

    # You can also create a different file in the same directories or new ones
    another_file = "outputs.tf"
    another_content = ""
    create_same_file_in_multiple_directories(another_file, another_content, target_directories)