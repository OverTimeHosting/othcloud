#!/bin/bash

# Configuration script for OTHcloud installation
# Run this before pushing to GitHub to set up your repository details

echo "🔧 OTHcloud Installation Setup"
echo "================================"
echo ""

# Get GitHub username
read -p "Enter your GitHub username: " github_username
read -p "Enter your repository name (default: othcloud): " repo_name
repo_name=${repo_name:-othcloud}

read -p "Enter your GitHub branch (default: main): " github_branch  
github_branch=${github_branch:-main}

echo ""
echo "📝 Configuration:"
echo "   GitHub Username: $github_username"
echo "   Repository: $repo_name"  
echo "   Branch: $github_branch"
echo ""

read -p "Is this correct? [Y/n]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo "❌ Setup cancelled."
    exit 1
fi

# Update install.sh with correct repository URL
sed -i "s|OverTimeHosting|$github_username|g" install.sh
sed -i "s|othcloud\.git|$repo_name.git|g" install.sh

# Update README.md with correct URLs
sed -i "s|OverTimeHosting|$github_username|g" README.md
sed -i "s|othcloud/main|$repo_name/$github_branch|g" README.md

# Update INSTALL.md with correct URLs  
sed -i "s|OverTimeHosting|$github_username|g" INSTALL.md
sed -i "s|othcloud/main|$repo_name/$github_branch|g" INSTALL.md

# Update setup.sh
sed -i "s|OverTimeHosting|$github_username|g" setup.sh
sed -i "s|othcloud/main|$repo_name/$github_branch|g" setup.sh

# Make scripts executable
chmod +x install.sh setup.sh

echo ""
echo "✅ Configuration complete!"
echo ""
echo "📋 Next steps:"
echo "1. Commit and push these changes to GitHub:"
echo "   git add ."
echo "   git commit -m \"Add installation script\""
echo "   git push origin $github_branch"
echo ""
echo "2. Your one-line install command will be:"
echo "   curl -sSL https://raw.githubusercontent.com/$github_username/$repo_name/$github_branch/install.sh | bash"
echo ""
echo "3. Test the installation on a clean Ubuntu/Debian server"
echo ""
echo "🚀 Ready to deploy!"