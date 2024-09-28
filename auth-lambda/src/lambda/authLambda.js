const mongoose = require('mongoose');
const Cliente = require('./models/cliente'); // Certifique-se de ter o modelo Cliente no mesmo repositório

// Conectar ao MongoDB
mongoose.connect(process.env.MONGO_URI, {
    useNewUrlParser: true,
    useUnifiedTopology: true
});

exports.handler = async (event) => {
    const { cpf } = JSON.parse(event.body);

    if (!cpf) {
        return {
            statusCode: 400,
            body: JSON.stringify({ message: 'CPF é obrigatório' })
        };
    }

    try {
        const cliente = await Cliente.findOne({ cpf });

        if (cliente) {
            // Autenticação bem-sucedida, retorna um token JWT ou outros dados necessários
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: 'Cliente autenticado com sucesso',
                    cliente,
                    token: 'jwt-token-exemplo' // Gerar JWT com base nos dados do cliente
                })
            };
        } else {
            return {
                statusCode: 404,
                body: JSON.stringify({ message: 'Cliente não encontrado' })
            };
        }
    } catch (error) {
        return {
            statusCode: 500,
            body: JSON.stringify({ message: 'Erro no servidor', error: error.message })
        };
    }
};