MODEL="$1"
if [ -z "$MODEL" ]; then
    echo "Usage: $0 <model>"
    exit 1
fi

find test/code_blocks/structured-outputs -type f -exec sed -i '' "s@mistralai/mistral-nemo-12b-instruct/fp-8@$MODEL@g" {} +